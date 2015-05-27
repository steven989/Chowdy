class CreateRefunds < ActiveRecord::Migration
  def change
    create_table :refunds do |t|
        t.string :stripe_customer_id
        t.date :refund_week
        t.date :charge_week
        t.string :charge_id
        t.integer :amount_refunded
        t.integer :meals_refunded
        t.string :refund_reason

      t.timestamps
    end
  end
end
