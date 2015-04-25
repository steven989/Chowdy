class Customer < ActiveRecord::Base

    belongs_to :user, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
    has_many :feedbacks, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

    def delete_with_stripe
        customer = Stripe::Customer.retrieve(stripe_customer_id)
        if customer.delete
            self.destroy
        end
    end

end
