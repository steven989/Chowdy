class Customer < ActiveRecord::Base

    belongs_to :user, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
    has_many :feedbacks, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :stop_requests, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :stop_queues, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :failed_invoices, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

    def delete_with_stripe
        customer = Stripe::Customer.retrieve(stripe_customer_id)
        if customer.delete
            self.destroy
        end
    end

    def create_referral_code
        base = self.name.split(/\s/)[0].downcase
        base_last = self.name.split(/\s/)[1][0..3].downcase
        numerical = Customer.where("name ilike ?", "%#{base}%").length
        code_candidate = base.to_s + base_last.to_s + (numerical*rand(5..10)).to_s
        while Customer.where(referral_code: code_candidate).length > 0 do
            numerical += 11
            code_candidate = base.to_s + numerical.to_s
        end
        self.update_attribute(:referral_code, code_candidate)
    end

end
