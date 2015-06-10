class CreatePromotionRedemptions < ActiveRecord::Migration
  def change
    create_table :promotion_redemptions do |t|
        t.string :stripe_customer_id
        t.integer :promotion_id
        

      t.timestamps null: false
    end
  end
end
