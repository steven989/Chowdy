class PartnerProductOrderSummary < ActiveRecord::Base
    belongs_to :partner_product, foreign_key: :product_id, primary_key: :id
end
