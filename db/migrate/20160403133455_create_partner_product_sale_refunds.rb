class CreatePartnerProductSaleRefunds < ActiveRecord::Migration
  def change
    create_table :partner_product_sale_refunds do |t|
        t.string :stripe_refund_id
        t.integer :partner_product_sale_id
        t.integer :partner_product_sale_detail_id
        t.integer :amount_refunded
        t.string :refund_reason
      t.timestamps null: false
    end
  end
end
