class PartnerProductSaleDetail < ActiveRecord::Base
    belongs_to :partner_product_sale
    belongs_to :partner_product
end
