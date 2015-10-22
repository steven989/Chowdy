class CreateGiftRemains < ActiveRecord::Migration
  def change
    create_table :gift_remains do |t|
        t.integer :gift_id
        t.integer :amount_remaining
        t.date :date_to_process
      t.timestamps null: false
    end
  end
end
