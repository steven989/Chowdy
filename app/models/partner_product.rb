class PartnerProduct < ActiveRecord::Base
    belongs_to :vendor
    has_many :partner_product_sale_details

    store :photos, accessors: [ :photo_1, :photo_2, :photo_3, :photo_4 ], coder: JSON

    mount_uploader :photos, PartnerProductUploader
end
