class AddMealCountsToQueue < ActiveRecord::Migration
  def change
    add_column :stop_queues, :updated_meals, :integer
    add_column :stop_queues, :updated_reg_mon, :integer
    add_column :stop_queues, :updated_reg_thu, :integer
    add_column :stop_queues, :updated_grn_mon, :integer
    add_column :stop_queues, :updated_grn_thu, :integer
  end
end
