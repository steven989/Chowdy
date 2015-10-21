class Gift < ActiveRecord::Base

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

        rescue => error
                puts '---------------------------------------------------'
                puts "something went wrong creating a gift"
                puts error.message
                puts '---------------------------------------------------' 
                CustomerMailer.rescued_error(customer,"something went wrong creating gift: "+error.message.inspect).deliver
        else
            CustomerMailer.gift_sender_confirmation(gift).deliver #delay this
            CustomerMailer.gift_recipient_notification(gift).deliver #delay this
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

end
