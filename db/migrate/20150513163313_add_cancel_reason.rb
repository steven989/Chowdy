class AddCancelReason < ActiveRecord::Migration
  def change
    add_column :stop_requests, :cancel_reason, :string
  end
end
