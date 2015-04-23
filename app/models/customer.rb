class Customer < ActiveRecord::Base

    def delete_with_stripe
        customer = Stripe::Customer.retrieve(stripe_customer_id)
        if customer.delete
            self.destroy
        end
    end

end
