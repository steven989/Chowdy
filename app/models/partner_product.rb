class PartnerProduct < ActiveRecord::Base
    belongs_to :vendor
    has_many :partner_product_sale_details

    mount_uploaders :photos, PartnerProductUploader #for uploading multiple files, this has to be mount_uploaders insteat of mount_uploader
end
