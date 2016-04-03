class CreatePartnerProductSales < ActiveRecord::Migration
  def change
    create_table :partner_product_sales do |t|
        t.string :stripe_customer_id
        t.date :delivery_week
        t.integer :partner_product_id
        t.integer :quantity_ordered
        t.string :order_status
      t.timestamps null: false
    end
  end
end
