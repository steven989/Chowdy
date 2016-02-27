class PartnerProductSale < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :partner_product_sale_details
end
