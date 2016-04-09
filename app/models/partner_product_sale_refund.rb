class PartnerProductSaleRefund < ActiveRecord::Base
    belongs_to :partner_product_sale
    belongs_to :partner_product_sale_detail
end
