class CreatePartnerProductOrderSummaries < ActiveRecord::Migration
  def change
    create_table :partner_product_order_summaries do |t|
        t.integer :product_id
        t.date :delivery_date
        t.integer :ordered_quantity

      t.timestamps null: false
    end
  end
end
