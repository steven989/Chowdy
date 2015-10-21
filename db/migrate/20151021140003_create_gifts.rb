class CreateGifts < ActiveRecord::Migration
  def change
    create_table :gifts do |t|
        t.string :sender_stripe_customer_id
        t.string :sender_name
        t.string :sender_email
        t.string :recipient_name
        t.string :recipient_email
        t.string :charge_id
        t.integer :original_gift_amount
        t.integer :remaining_gift_amount
        t.boolean :pay_delivery
        t.string :gift_code


      t.timestamps null: false
    end
  end
end
