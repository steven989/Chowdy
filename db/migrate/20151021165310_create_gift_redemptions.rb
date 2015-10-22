class CreateGiftRedemptions < ActiveRecord::Migration
  def change
    create_table :gift_redemptions do |t|
        t.integer :gift_id
        t.string :stripe_customer_id
        t.integer :amount_redeemed
        t.integer :amount_remaining

      t.timestamps null: false
    end
  end
end
