class AddTotalNextWeekMealToDailySnapshot < ActiveRecord::Migration
  def change
    add_column :daily_snapshots, :next_week_total, :integer
  end
end
