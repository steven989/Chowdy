class CreateDailySnapshots < ActiveRecord::Migration
  def change
    create_table :daily_snapshots do |t|
        t.date :date
        t.integer :active_customers_including_pause
        t.integer :active_customers_excluding_pause

      t.timestamps null: false
    end
  end
end
