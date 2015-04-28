class AddEndDateToQueue < ActiveRecord::Migration
  def change
    add_column :stop_queues, :end_date, :date
  end
end
