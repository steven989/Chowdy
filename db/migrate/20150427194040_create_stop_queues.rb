class CreateStopQueues < ActiveRecord::Migration
  def change
    create_table :stop_queues do |t|
        t.date :associated_cutoff
        t.string :stop_type
        t.string :stripe_customer_id

      t.timestamps
    end
  end
end
