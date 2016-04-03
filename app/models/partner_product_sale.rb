class PartnerProductSale < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :partner_product_sale_details
    has_many :partner_product_sale_refunds


    def create_unique_id
        first_letters = "PS"
        five_digit = rand(1000..9999).to_s
        chars = ('A'..'Z').to_a
        rand_letters = (0...2).collect { chars[Kernel.rand(chars.length)] }.join

        code_candidate = first_letters + five_digit + rand_letters

        while PartnerProductSale.where(sale_id: code_candidate).length > 0 do
            six_digit = rand(10000..99999).to_s
            rand_letters = (0...3).collect { chars[Kernel.rand(chars.length)] }.join
            code_candidate = first_letters + six_digit + rand_letters
        end
        self.update_attribute(:sale_id, code_candidate)
        code_candidate
    end

    def self.pull_date
        delivery_date = Chowdy::Application.closest_date(1,1)
        delivery_date
    end


    def cancel_order(force_change=false,admin=false)
        scheduled_delivery_date = self.delivery_date
        cut_off_date = Chowdy::Application.closest_date(-1,4,scheduled_delivery_date)

        if Date.today <= cut_off_date || force_change
            begin            
                refund = Stripe::Refund.create(charge:self.stripe_charge_id)
            rescue => error
                {result:"fail", message:"#{error.message}"}
            else
                self.partner_product_sale_details.each do |ppsd|
                    PartnerProductSaleRefund.create(
                        stripe_refund_id: refund.id,
                        partner_product_sale_id: self.id,
                        partner_product_sale_detail_id:ppsd.id,
                        amount_refunded:ppsd.sale_price_before_hst_in_cents,
                        refund_reason:"Order #{self.sale_id} (#{self.delivery_date.strftime("%A %B %e, %Y")} delivery) cancelled by #{admin ? 'admin' : 'customer'}"
                    )    
                end
                self.update_attributes(order_status:"Cancelled")
                {result:"success", message:"Order #{self.sale_id} cancelled"}
                if self.customer.user
                    self.customer.user.log_activity("Order #{self.sale_id} cancelled by #{admin ? 'admin' : 'customer'}")
                end
            end
        else
            {result:"fail", message:"Order could not be cancelled: the cut off date to cancel this order was #{cut_off_date.("%A %B %e, %Y")}. Please email help@chowdy.ca for assistance."}
        end

    end


    def modify_order(updated_order_array,force=false,update_volume=true,admin=false)
        if updated_order_array.blank?
            result = {result:"fail", message:"You must pass an array of updated order"}
        else
            scheduled_delivery_date = self.delivery_date
            cut_off_date = Chowdy::Application.closest_date(-1,4,scheduled_delivery_date)

            if Date.today <= cut_off_date || force_change
                cart = updated_order_array.map do |uoa|
                    {
                        product_id:product_id,
                        quantity:quantity,
                        product_name:product_name,
                        vendor_name:vendor_name,
                        price:price
                    }
                end
                cart.delete_if {|ci| ci[:quantity] <= 0 }
                if cart.blank? || cart.map {|c| c[:quantity]}.sum == 0 
                    result = {result:"fail", message: "You must select at least one product"}
                else 
                    total_dollars_before_hst = cart.map{|c| c[:price]*c[:quantity] }.sum
                    total_dollars_after_hst = (total_dollars_before_hst * 1.13).round
                    
                    if total_dollars_after_hst > self.total_amount_including_hst_in_cents
                        charge_description = "Extra charge from updating order: #{cart.map{|c| c[:quantity].to_s+' '+c[:product_name]+' from '+c[:vendor_name]+': unit price $'+((c[:price].to_f/100).round(2).to_s)}.join(', ')}"
                        extra_charge = total_dollars_after_hst - self.total_amount_including_hst_in_cents

                        begin
                            charge = Stripe::Charge.create(
                                amount: extra_charge,
                                currency: 'CAD',
                                customer: self.customer.stripe_customer_id,
                                description: charge_description,
                                metadata: {email: self.customer.email},
                                statement_descriptor: 'CHOWDY MKTPLCE PRCHSE'
                            )
                        rescue Stripe::CardError => error
                            result = {result:"fail", message: "Purchase could not be update. Your card was declined"}
                        rescue => error
                            result = {result:"fail", message: "An error was encountered during the trasaction. Please try again"}
                        else
                            if update_volume
                                updated_charge_array = self.stripe_charge_id
                                updated_charge_array.push(charge.id)
                                self.update_attributes(total_amount_including_hst_in_cents:total_dollars_after_hst,stripe_charge_id:updated_charge_array)

                                self.partner_product_sale_details.each do |ppsd|
                                    if PartnerProductOrderSummary.where(product_id:ppsd.partner_product_id,delivery_date:self.delivery_date).length == 1
                                        quantity = PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).take.ordered_quantity - ppsd.quantity
                                        PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).take.update_attributes(ordered_quantity:quantity)
                                    end
                                    ppsd.destroy
                                end

                                cart.each do |c|
                                    PartnerProductSaleDetail.create(
                                        partner_product_sale_id:self.id,
                                        partner_product_id:c[:product_id],
                                        quantity:c[:quantity],
                                        cost_in_cents:PartnerProduct.find(c[:product_id]).cost_in_cents,
                                        sale_price_before_hst_in_cents:c[:price]
                                    )  

                                    if PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).length == 1
                                        quantity = PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).take.ordered_quantity + c[:quantity]
                                        PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).take.update_attributes(ordered_quantity:quantity)
                                    elsif PartnerProductOrderSummary.where(product_id:c[:product_id],delivery_date:self.delivery_date).length == 0
                                        PartnerProductOrderSummary.create(product_id:c[:product_id],delivery_date:self.delivery_date,ordered_quantity:c[:quantity])
                                    end
                                end
                            end
                            result = {result:"success", message: "Order #{self.sale_id} is updated"}
                            if self.customer.user
                                self.customer.user.log_activity("Order #{self.sale_id} updated by #{admin ? 'admin' : 'customer'}; extra charge of $#{extra_charge.to_f/100}")
                            end
                        end
                    elsif total_dollars_after_hst == self.total_amount_including_hst_in_cents
                        result = {result:"success", message: "Order updated"}
                        if self.customer.user
                            self.customer.user.log_activity("Order updated by #{admin ? 'admin' : 'customer'} with no effect on total charge")
                        end
                    else
                        refund_amount = self.total_amount_including_hst_in_cents - total_dollars_after_hst
                        refund_amount_loop = self.total_amount_including_hst_in_cents - total_dollars_after_hst
                        list_of_charges = self.stripe_charge_id
                        max_loop_count = [list_of_charges.length - 1,0].max
                        min_loop_count = 0

                        if max_loop_count == 0
                            result = {result:"fail", message: "We could not locate any charge to refund do"}
                        else
                            begin
                                loop_var = true
                                while loop_var && (min_loop_count <= max_loop_count)
                                    stripe_charge = list_of_charges[min_loop_count]
                                    charge = Stripe::Charge.retrieve(stripe_charge)
                                    available_charge_amount = charge.amount - charge.amount_refunded

                                    if available_charge_amount >= refund_amount_loop
                                        stripe_refund_response = charge.refunds.create(amount:refund_amount_loop)
                                        loop_var = false
                                    else
                                        stripe_refund_response = charge.refunds.create(amount:available_charge_amount)
                                        refund_amount_loop -= available_charge_amount
                                        min_loop_count += 1
                                    end                                
                                end
                            rescue => error
                                result = {result:"fail", message: "#{error.message}"}
                            else
                                PartnerProductSaleRefund.create(
                                    stripe_refund_id: stripe_refund_response.id,
                                    partner_product_sale_id: self.id,
                                    partner_product_sale_detail_id:nil,
                                    amount_refunded:refund_amount,
                                    refund_reason:"Order #{self.sale_id} (#{self.delivery_date.strftime("%A %B %e, %Y")} delivery) updated by #{admin ? 'admin' : 'customer'} resulting in refund"
                                )
                                if self.customer.user
                                    self.customer.user.log_activity("Order updated by #{admin ? 'admin' : 'customer'} resulting in a refund of $#{refund_amount.to_f/100}")
                                end
                                result = {result:"success", message: "Order #{self.sale_id} is updated"}
                            end
                        end
                    end
                end
            else
                result = {result:"fail", message:"Order could not be cancelled: the cut off date to cancel this order was #{cut_off_date.("%A %B %e, %Y")}. Please email help@chowdy.ca for assistance."}
            end
        end

        result
    end

    def lump_sum_refund_not_linked_to_items(amount)

        refund_amount = amount
        refund_amount_loop = amount
        list_of_charges = self.stripe_charge_id
        max_loop_count = [list_of_charges.length - 1,0].max
        min_loop_count = 0

        if max_loop_count == 0
            result = {result:"fail", message: "We could not locate any charge to refund do"}
        else
            begin
                loop_var = true
                while loop_var && (min_loop_count <= max_loop_count)
                    stripe_charge = list_of_charges[min_loop_count]
                    charge = Stripe::Charge.retrieve(stripe_charge)
                    available_charge_amount = charge.amount - charge.amount_refunded

                    if available_charge_amount >= refund_amount_loop
                        stripe_refund_response = charge.refunds.create(amount:refund_amount_loop)
                        loop_var = false
                    else
                        stripe_refund_response = charge.refunds.create(amount:available_charge_amount)
                        refund_amount_loop -= available_charge_amount
                        min_loop_count += 1
                    end                                
                end
            rescue => error
                result = {result:"fail", message: "#{error.message}"}
            else
                if refund_amount_loop > 0
                    amount_actually_refunded = refund_amount - refund_amount_loop
                    result = {result:"success", message: "Lump sum of $#{amount_actually_refunded.to_f/100} refunded; $#{refund_amount_loop.to_f/100} could not be refunded because there is not enough amount in the original charge"}
                else 
                    amount_actually_refunded = refund_amount
                    result = {result:"success", message:"Lump sum of $#{amount_actually_refunded.to_f/100} refunded"}
                end

                PartnerProductSaleRefund.create(
                    stripe_refund_id: stripe_refund_response.id,
                    partner_product_sale_id: self.id,
                    partner_product_sale_detail_id:nil,
                    amount_refunded:amount_actually_refunded,
                    refund_reason:"Lump sum refund"
                )
                if self.customer.user
                    self.customer.user.log_activity("Lump sum of $#{amount_actually_refunded.to_f/100} refunded by the admin")
                end  
            end
        end
        result
    end

end
