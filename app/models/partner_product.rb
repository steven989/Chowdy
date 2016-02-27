class PartnerProduct < ActiveRecord::Base
    belongs_to :vendor
    has_many :partner_product_sale_details
end
