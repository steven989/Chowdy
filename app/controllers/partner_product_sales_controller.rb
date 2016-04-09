class PartnerProductSalesController < ApplicationController

    def order
        customer = current_user.customer
        puts params.inspect 
        raw_cart = JSON.parse(params["cart"])

        cart = raw_cart.map do |c|
            {
                product_id: c['product_id'].to_i,
                quantity: c['quantity'].to_i,
                product_name: PartnerProduct.find(c['product_id'].to_i).product_name,
                vendor_name: PartnerProduct.find(c['product_id'].to_i).vendor.vendor_name,
                price: PartnerProduct.find(c['product_id'].to_i).price_in_cents
            }
        end

        cart.delete_if {|ci| ci[:quantity] <= 0 }

        if cart.blank? || cart.map {|c| c[:quantity]}.sum == 0 
            result = {result:"fail", message: "You must select at least one product"}
        else 

            total_dollars_before_hst = cart.map{|c| c[:price]*c[:quantity] }.sum
            total_dollars_after_hst = (total_dollars_before_hst * 1.13).round
            charge_description = "#{cart.map{|c| c[:quantity].to_s+' '+c[:product_name]+' from '+c[:vendor_name]+': unit price $'+((c[:price].to_f/100).round(2).to_s)}.join(', ')}"

            begin
                charge = Stripe::Charge.create(
                    amount: total_dollars_after_hst,
                    currency: 'CAD',
                    customer: customer.stripe_customer_id,
                    description: charge_description,
                    metadata: {email: customer.email},
                    statement_descriptor: 'CHOWDY MKTPLCE PRCHSE'
                )
            rescue Stripe::CardError => error
               result = {result:"fail", message: "Purchase could not be completed. Your card was declined"}
            rescue => error
               result = {result:"fail", message: "An error was encountered during the trasaction. Please try again"}
            else
                if pps = PartnerProductSale.create(stripe_customer_id:customer.stripe_customer_id, total_amount_including_hst_in_cents:total_dollars_after_hst,order_status:'Received',delivery_date: PartnerProductDeliveryDate.first.delivery_date, stripe_charge_id:[charge.id])
                    cart.each do |c|
                        PartnerProductSaleDetail.create(
                            partner_product_sale_id:pps.id,
                            partner_product_id:c[:product_id],
                            quantity:c[:quantity],
                            cost_in_cents:PartnerProduct.find(c[:product_id]).cost_in_cents,
                            sale_price_before_hst_in_cents:PartnerProduct.find(c[:product_id]).price_in_cents
                        )                    
                    
                        if PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:PartnerProductDeliveryDate.first.delivery_date).length == 1
                            quantity = PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:PartnerProductDeliveryDate.first.delivery_date).take.ordered_quantity + c[:quantity]
                            PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:PartnerProductDeliveryDate.first.delivery_date).take.update_attributes(ordered_quantity:quantity)
                        elsif PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:PartnerProductDeliveryDate.first.delivery_date).length == 0
                            PartnerProductOrderSummary.create(product_id:c[:product_id],delivery_date:PartnerProductDeliveryDate.first.delivery_date,ordered_quantity:c[:quantity])
                        end

                    end
                    purchase_id = pps.create_unique_id
                    current_user.log_activity("Customer made purchase from marketplace. Order ID: #{purchase_id}")
                    CustomerMailer.delay.email_purchase_confirmation(customer,pps,total_dollars_after_hst)
                    result = {result:"success", message: "Your order has been placed. You will receive a confirmation email receipt from us shortly with your order details. If you do not receive an email within 10 minutes, please email <a href='mailto:help@chowdy.ca'>help@chowdy.ca</a> for assistance"}
                else
                    result = {result:"fail", message: "An error has occurred"}
                end
            end
        end

        respond_to do |format| 
            format.json {
                render json: result
            }
        end
    end

    def weekly_sales_report #this is to produce the list to package items to ship

        delivery_date = PartnerProductSale.pull_date
        sales = PartnerProductSale.where{(delivery_date == delivery_date) && (order_status !~ "Cancelled")}

        customers = sales.map {|s| s.customer }
        customers = customers.uniq

        @customer_order_array = customers.map do |c|
            sales_details_array_raw = c.partner_product_sales.map {|pps| pps.partner_product_sale_details.map {|ppsd| {quantity:ppsd.quantity,product:ppsd.partner_product.product_name,size:ppsd.partner_product.product_size,id:ppsd.partner_product.id,vendor:ppsd.partner_product.vendor.vendor_name} } }.flatten
            sales_details_array = []
            sales_details_array_raw.each { |sdar|

                if sales_details_array.select {|sda| sda[:id] == sdar[:id]}.length > 0
                    sales_details_array.map! {|e| e[:id] == sdar[:id] ? {quantity:e[:quantity] + sdar[:quantity],product:e[:product],size:e[:size],id:e[:id],vendor:e[:vendor]} : e}
                else
                    sales_details_array.push({quantity:sdar[:quantity],product:sdar[:product],size:sdar[:size],id:sdar[:id],vendor:sdar[:vendor]})
                end
            }


            {
            customer_id:c.id,
            email:c.email,
            name:c.name,
            delivery_address:c.delivery_address,
            phone_number:c.phone_number,
            order: sales_details_array.map{|sda| "#{sda[:quantity]} #{sda[:product]} (#{sda[:size]}) from #{sda[:vendor]}"}.join("  ------|------  ")
            }
        end

        respond_to do |format|
            format.csv { 
                disposition = "attachment; filename='marketplace_deliveries_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv'"
                response.headers['Content-Disposition'] = disposition
                if @customer_order_array.blank?
                    send_data  CSV.generate {|csv| csv << ["customer_id","email","name","delivery_address","phone_number","order"]}, type: 'text/csv; charset=utf-8; header=present', disposition: disposition, filename: "marketplace_deliveries_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv"
                else 
                    send_data  CSV.generate {|csv| csv << @customer_order_array.first.keys; @customer_order_array.each {|data| csv << data.values}}, type: 'text/csv; charset=utf-8; header=present', disposition: disposition, filename: "marketplace_deliveries_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv"
                end
            }
        end  
    end

    def weekly_sales_total_report #this will aggregate the amount ordered by customers for vendor purchase purposes

        delivery_date = PartnerProductSale.pull_date
        sales = PartnerProductSale.where{(delivery_date == delivery_date) && (order_status !~ "Cancelled")}

        products_to_order = []

        sales.each do |pps|
            pps.partner_product_sale_details.each do |ppsd|
                
                if products_to_order.select {|pto| pto[:product_id] == ppsd.partner_product_id}.length > 0
                    products_to_order.map! {|e| e[:product_id] == ppsd.partner_product_id ? {product_id:ppsd.partner_product_id, product_name:ppsd.partner_product.product_name,product_size:ppsd.partner_product.product_size,vendor_product_sku:ppsd.partner_product.vendor_product_sku, vendor:ppsd.partner_product.vendor.vendor_name, cost:e[:cost].to_i+ppsd.partner_product.cost_in_cents.to_i, quantity:e[:quantity]+ppsd.quantity} : e}
                else
                    products_to_order.push({product_id:ppsd.partner_product_id, product_name:ppsd.partner_product.product_name,product_size:ppsd.partner_product.product_size,vendor_product_sku:ppsd.partner_product.vendor_product_sku, vendor:ppsd.partner_product.vendor.vendor_name, cost:ppsd.partner_product.cost_in_cents, quantity:ppsd.quantity})
                end
            end
        end

        respond_to do |format|
            format.csv { 
                disposition = "attachment; filename='marketplace_aggregate_order_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv'"
                response.headers['Content-Disposition'] = disposition
                if products_to_order.blank?
                    send_data  CSV.generate {|csv| csv << ["product_id","product_name","product_size","vendor_product_sku","vendor","cost","quantity"]}, type: 'text/csv; charset=utf-8; header=present', disposition: disposition, filename: "marketplace_aggregate_order_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv"
                else 
                    send_data  CSV.generate {|csv| csv << products_to_order.first.keys; products_to_order.each {|data| csv << data.values}}, type: 'text/csv; charset=utf-8; header=present', disposition: disposition, filename: "marketplace_aggregate_order_week_of_#{delivery_date.strftime("%Y_%m_%d")}.csv"
                end
            }
        end 
    end

    def search_order_by_customer
        keyword = params[:keyword]
        customer_results = Customer.search_by_name_or_email(keyword)
        @results = []
        
        customer_results.each do |cr|
            cr.partner_product_sales.each do |pps|
                @results.push({stripe_customer_id: pps.customer.stripe_customer_id,name:pps.customer.name, email:pps.customer.email, customer_id:pps.customer.id,sale_id:pps.sale_id,total_amount_including_hst_in_cents:pps.total_amount_including_hst_in_cents, delivery_date:pps.delivery_date, created_at:pps.created_at, order_status:pps.order_status})
            end
        end

        @results = @results.sort {|a,b| [b[:customer_id],b[:created_at]] <=> [a[:customer_id],a[:created_at]] }
 
        respond_to do |format|
          format.html {
            render partial: 'matched_sales_headers'
          }      
        end          
        
    end

    def search_order_details_by_id
        sales_id = params[:sales_id]
        sales = PartnerProductSale.where(sale_id:sales_id)
        unless sales.length != 1
            @sales_details = sales.take.partner_product_sale_details
        end

        respond_to do |format|
          format.html {
            render partial: 'matched_sales_details'
          }      
        end  
    end

    def view_orders
        customer = current_user.role == "admin" ? Customer.find(params[:customer_id]) : current_user.customer
        @orders = customer.partner_product_sales.where{order_status !~ 'Cancelled'}.order(created_at: :desc)

        respond_to do |format|
          format.html {
            render partial: 'view_orders'
          }      
        end 
    end

    def cancel_order
        force_cancel = params[:force_cancel]
        admin = current_user.role == "admin"

        order = PartnerProductSale.where(sale_id:params[:sale_id])
        if order.length == 1
            result = order.take.cancel_order(force_cancel,admin)
            if result[:result] == 'success' 
                CustomerMailer.delay.order_cancellation_confirmation(order.take.customer,order.take)
            end
        elsif order.length == 0
            result = {result:"fail", message:"Could not find order #{params[:sale_id]}"}
        else
            result = {result:"fail", message:"Order could not be cancelled. Multiple orders with ID #{params[:sale_id]} found"}
        end

        respond_to do |format|
          format.json {
            render json: result
          }      
        end     
    end

    def edit_order
        sale_ids = params[:sale_id]
        @order = PartnerProductSale.where{(sale_id =~ sale_ids) & (order_status !~ "Cancelled")}

        if @order.length == 1
            scheduled_delivery_date = @order.take.delivery_date
            cut_off_date = Chowdy::Application.closest_date(-1,4,scheduled_delivery_date)
            @editable = Date.today <= cut_off_date

            @partner_product_sale_details = @order.take.partner_product_sale_details
            @cart = @partner_product_sale_details.map {|ppsd| {product_id:ppsd.partner_product_id, quantity:ppsd.quantity, price:ppsd.sale_price_before_hst_in_cents} }
            @subtotal = @partner_product_sale_details.map{|ppsd| ppsd.quantity * ppsd.sale_price_before_hst_in_cents}.sum 
            @total = (@subtotal * 1.13).round
            @hst = @total - @subtotal
        end

        respond_to do |format|
          format.html {
            render partial: 'edit_order'
          }      
        end   
    end

    def update_order
        update_volume = params[:update_volume]

        admin = current_user.role == "admin"
        force_update = admin && params[:force_update]
        updated_order_array_raw = params[:updated_order_array]
        order = PartnerProductSale.where(sale_id:params[:sale_id])

        if order.length == 1 
            updated_order_array = updated_order_array_raw.map do |order_item| 
                matched_product = PartnerProduct.find(order_item[:product_id])
                {           
                product_id:order_item[:product_id],
                quantity:order_item[:quantity],
                product_name:matched_product.product_name,
                vendor_name:matched_product.vendor.vendor_name,
                price:order.take.partner_product_sale_details.where(partner_product_id:order_item[:product_id]).take.sale_price_before_hst_in_cents
                } 
            end
            updated_order_array.delete_if {|ci| ci[:quantity] <= 0 }
            result = order.take.modify_order(updated_order_array,force_update,update_volume,admin)
            if result[:result] == "success"
                total_dollars = result[:new_amount].to_i
                diff = result[:new_amount].to_i - result[:old_amount].to_i
                CustomerMailer.delay.order_modification_confirmation(order.take.customer,order,total_dollars, diff,order.take.delivery_date)
            end
        elsif  order.length == 0 
            result = {result:"fail", message:"Could not find order #{params[:sale_id]}"}
        else
            result = {result:"fail", message:"Order could not be cancelled. Multiple orders with ID #{params[:sale_id]} found"}
        end

        respond_to do |format|
          format.json {
            render json: result
          }      
        end    
    end


    def refund
        order = PartnerProductSale.where(sale_id:params[:sale_id])
        refund_amount = params[:refund_amount]

        if order.length == 1
            result = lump_sum_refund_not_linked_to_items(refund_amount)
        elsif  order.length == 0 
            result = {result:"fail", message:"Could not find order #{params[:sale_id]}"}
        else
            result = {result:"fail", message:"Order could not be cancelled. Multiple orders with ID #{params[:sale_id]} found"}
        end

        respond_to do |format|
          format.json {
            render json: result
          }      
        end    
    end

end
