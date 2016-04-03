class CreatePartnerProducts < ActiveRecord::Migration
  def change
    create_table :partner_products do |t|
        t.integer :vendor_id
        t.integer :product_id
        t.string :product_name
        t.text :product_description
        t.string :product_size
        t.string :vendor_product_sku
        t.string :vendor_product_upc
        t.integer :cost_in_cents
        t.integer :suggested_retail_price_in_cents
        t.integer :price_in_cents
        t.string :url_of_photo
      t.timestamps null: false
    end
  end
end
