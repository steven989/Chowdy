class AddMoreColumnsToSnapshot < ActiveRecord::Migration
  def change
    add_column :daily_snapshots, :total_meals, :integer
  end
end
