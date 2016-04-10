class PartnerProduct < ActiveRecord::Base
    belongs_to :vendor
    has_many :partner_product_sale_details
    has_many :partner_product_order_summaries, foreign_key: :product_id, primary_key: :id

    mount_uploaders :photos, PartnerProductUploader #for uploading multiple files, this has to be mount_uploaders insteat of mount_uploader

    def self.products_to_display
        PartnerProduct.find_by_sql("Select a.* From partner_products a left join partner_product_order_summaries b on a.id = b.product_id and b.delivery_date = '#{PartnerProductDeliveryDate.first.delivery_date}' where coalesce(b.ordered_quantity,0) < a.max_quantity and a.available = true Order By a.created_at desc")
    end

end
