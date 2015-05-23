class CreatePromotions < ActiveRecord::Migration
  def change
    create_table :promotions do |t|
        t.date :start_date
        t.date :end_date
        t.string :code
        t.string :stripe_coupon_id
        t.boolean :immediate_refund
        t.boolean :active
        t.integer :redemptions

      t.timestamps
    end
  end
end
