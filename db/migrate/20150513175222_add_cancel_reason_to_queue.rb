class AddCancelReasonToQueue < ActiveRecord::Migration
  def change
    add_column :stop_queues, :cancel_reason, :string
  end
end
