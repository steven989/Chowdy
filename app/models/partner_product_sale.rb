class PartnerProductSale < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :partner_product_sale_details


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

end
