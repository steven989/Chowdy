class Gift < ActiveRecord::Base

    has_many :gift_redemptions
    has_many :gift_remains

    def self.create_from_sign_up(customer_id,customer_email)

        begin

            customer_id = customer_id
            customer_email = customer_email.downcase
            
            charge_data = Stripe::Charge.all(customer:customer_id, limit:1)[:data][0]

            charge_id = charge_data[:id]
            original_amount = charge_data[:amount]
            sender_name = charge_data[:metadata][:sender_name]
            recipient_name = charge_data[:metadata][:recipient_name]
            recipient_email = charge_data[:metadata][:recipient_email].downcase
            pay_delivery = charge_data[:metadata][:pay_delivery].downcase == "yes" ? true : false

            if customer_email == recipient_email
                charge_data.refunds.create
            else
                gift = Gift.create(
                    sender_stripe_customer_id:customer_id,
                    sender_name:sender_name,
                    sender_email:customer_email,
                    recipient_name:recipient_name,
                    recipient_email:recipient_email,
                    charge_id:charge_id,
                    original_gift_amount:original_amount,
                    remaining_gift_amount:original_amount,
                    pay_delivery:pay_delivery
                    )
                gift.create_gift_code
            end

        rescue => error
                puts '---------------------------------------------------'
                puts "something went wrong creating a gift"
                puts error.message
                puts '---------------------------------------------------' 
                CustomerMailer.rescued_error(customer,"something went wrong creating gift: "+error.message.inspect).deliver
        else
            if customer_email == recipient_email
                CustomerMailer.gift_sender_refund_notification(customer_email,sender_name,recipient_name).deliver #delay this
            else
                CustomerMailer.gift_sender_confirmation(gift).deliver #delay this
                CustomerMailer.gift_recipient_notification(gift).deliver #delay this
            end

        end
    end

    def reset_gift_amount(destroy_children=false)
        original_gift_amount = self.original_gift_amount
        self.update_attributes(remaining_gift_amount:original_gift_amount)

        if destroy_children
            self.gift_redemptions.destroy_all
            self.gift_remains.destroy_all
        end
    end

    def create_gift_code
        first_letter = "G"
        five_digit = rand(1000..9999).to_s
        initials = ((self.recipient_name + " " + self.sender_name).split(" ").map {|e| e[0].upcase}.join)[0..1]
        code_candidate = first_letter + five_digit + initials
        while Gift.where(gift_code: code_candidate).length > 0 do
            five_digit = rand(1000..9999).to_s
            initials = ((self.recipient_name + " " + self.sender_name).split(" ").map {|e| e[0].upcase}.join)[0..2]
            code_candidate = first_letter + five_digit + initials
        end
        self.update_attribute(:gift_code, code_candidate)
    end

    def self.check_gift_code(gift_code)
        gift = Gift.where("gift_code ilike ?",gift_code).take
        if gift.nil?
            {result:false, message:'Gift code does not exist'}
        else
            if gift.remaining_gift_amount == 0
                {result:false, message:'Gift code has already been redeemed'}
            else
                {result:true, message:'Gift code applied'}
            end
        end
    end

    def self.redeem_gift_code(gift_code=nil,charge=nil,customer=nil,immediate_refund=false)

        if Gift.check_gift_code(gift_code)[:result]
            gift = Gift.where("gift_code ilike ?",gift_code).take
            gift_amount = gift.remaining_gift_amount

            if immediate_refund
                stripe_charge = charge
                charge_amount = stripe_charge.amount
                discount_amount = [charge_amount,gift_amount].min

                begin
                    refund = charge.refunds.create(
                        amount:discount_amount,
                        metadata:{refund_reason:"Gift code #{gift_code}"}
                        )
                rescue => error
                    puts '---------------------------------------------------'
                    puts "something went wrong trying to refund customer using gift code"
                    puts error.message
                    puts '---------------------------------------------------' 
                    CustomerMailer.rescued_error(customer,"something went wrong trying to refund customer using gift code: "+error.message.inspect).deliver                    
                else
                    Refund.create(
                        stripe_customer_id: customer.stripe_customer_id, 
                        refund_week: SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date, 
                        charge_week:Time.at(stripe_charge.created).to_date,
                        charge_id: stripe_charge.id, 
                        meals_refunded:nil, 
                        amount_refunded: discount_amount, 
                        refund_reason:gift_code, 
                        stripe_refund_id: refund.id
                    )

                    remaining_gift_amount = gift_amount - discount_amount

                    gift.gift_redemptions.create(
                        stripe_customer_id:customer.stripe_customer_id,
                        amount_redeemed:discount_amount,
                        amount_remaining:remaining_gift_amount
                    )

                    gift.update_attributes(remaining_gift_amount:remaining_gift_amount)

                    if remaining_gift_amount > 0
                        Gift.redeem_gift_code(gift_code,nil,customer,false) #attach a negative invoice item 
                    else #if gift card is completely used up upon first redemption, then submit a cancel request dated the Thursday after the first pick up date
                        associated_cutoff = Chowdy::Application.closest_date(1,4,StartDate.first.start_date) #Thursday after customer starts
                        adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1,associated_cutoff)
                        customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:"Gift card #{gift_code} ran out")
                    end
                end
            else

                upcoming_charge_amount = Stripe::Customer.retrieve(customer.stripe_customer_id).subscriptions.retrieve(customer.stripe_subscription_id).plan.amount
                discount_amount = [upcoming_charge_amount,gift_amount].min

                if discount_amount > 0
                    begin
                        
                            Stripe::InvoiceItem.create(
                                customer: customer.stripe_customer_id,
                                amount: -discount_amount,
                                currency: 'CAD',
                                description: "Remaining amount of gift #{gift_code}"
                            )
                    rescue => error
                        puts '---------------------------------------------------'
                        puts "something went wrong trying to create a negative invoice using gift code"
                        puts error.message
                        puts '---------------------------------------------------' 
                        CustomerMailer.rescued_error(customer,"something went wrong trying to create a negative invoice using gift code: "+error.message.inspect).deliver                    
                    else
                        remaining_gift_amount = gift_amount - discount_amount

                        gift.gift_redemptions.create(
                            stripe_customer_id:customer.stripe_customer_id,
                            amount_redeemed:discount_amount,
                            amount_remaining:remaining_gift_amount
                        )

                        gift.update_attributes(remaining_gift_amount:remaining_gift_amount)

                        gift.gift_remains.create(
                            amount_remaining:remaining_gift_amount,
                            stripe_customer_id:customer.stripe_customer_id
                        )

                    end
                end
            end
        end
    end




end
