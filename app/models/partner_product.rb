class PartnerProduct < ActiveRecord::Base
    belongs_to :vendor
    has_many :partner_product_sale_details
    has_many :partner_product_order_summaries, foreign_key: :product_id, primary_key: :id

    mount_uploaders :photos, PartnerProductUploader #for uploading multiple files, this has to be mount_uploaders insteat of mount_uploader

    def self.products_to_display
        PartnerProduct.joins{partner_product_order_summaries.outer}.where{((partner_product_order_summaries.delivery_date == PartnerProductDeliveryDate.first.delivery_date) | (partner_product_order_summaries.delivery_date == nil)) & ((partner_product_order_summaries.ordered_quantity <= partner_products.max_quantity) | (partner_product_order_summaries.ordered_quantity == nil)) & (partner_products.available == true)}
    end

end
