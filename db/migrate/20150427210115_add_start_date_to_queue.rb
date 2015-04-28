class AddStartDateToQueue < ActiveRecord::Migration
  def change
    add_column :stop_queues, :start_date, :date
  end
end
