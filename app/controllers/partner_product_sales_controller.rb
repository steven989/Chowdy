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

        if cart.blank? || cart.map {|c| c[:quantity]}.sum == 0 
            result = {result:"fail", message: "You must select at least one product"}
        else 

            total_dollars_before_hst = cart.map{|c| c[:price]*c[:quantity] }.sum
            total_dollars_after_hst = (total_dollars_before_hst * 1.13).round
            charge_description = "#{cart.map{|c| c[:quantity].to_s+' '+c[:product_name]+' from '+c[:vendor_name]+': unit price $'+((c[:price].to_f/100).round(2).to_s)}.join(', ')}"

            begin
                Stripe::Charge.create(
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
                if pps = PartnerProductSale.create(stripe_customer_id:customer.stripe_customer_id, total_amount_including_hst_in_cents:total_dollars_after_hst,order_status:'Received')
                    cart.each do |c|
                        PartnerProductSaleDetail.create(
                            partner_product_sale_id:pps.id,
                            partner_product_id:c[:product_id],
                            quantity:c[:quantity],
                            cost_in_cents:PartnerProduct.find(c[:product_id]).cost_in_cents,
                            sale_price_before_hst_in_cents:PartnerProduct.find(c[:product_id]).price_in_cents
                        )                    
                    end
                    result = {result:"success", message: "Your order has been placed. You will receive an email receipt from us shortly"}
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
end
