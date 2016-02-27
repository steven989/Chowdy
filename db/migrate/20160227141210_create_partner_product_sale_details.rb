class CreatePartnerProductSaleDetails < ActiveRecord::Migration
  def change
    create_table :partner_product_sale_details do |t|
        t.integer :partner_product_sale_id
        t.integer :partner_product_id
        t.integer :quantity
        t.integer :cost_in_cents
        t.integer :sale_price_before_hst_in_cents
        t.integer :total_discounts_in_cents
      t.timestamps null: false
    end
  end
end
