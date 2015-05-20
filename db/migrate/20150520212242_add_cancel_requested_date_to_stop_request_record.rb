class AddCancelRequestedDateToStopRequestRecord < ActiveRecord::Migration
  def change
    add_column :stop_requests, :requested_date, :datetime
  end
end
