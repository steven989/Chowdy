class AddAverageCustomerDaysToDailySnapshot < ActiveRecord::Migration
  def change
    add_column :daily_snapshots, :active_customer_life_in_days, :float
  end
end
