class CreateStopRequests < ActiveRecord::Migration
  def change
    create_table :stop_requests do |t|
        t.string :stripe_customer_id
        t.string :request_type
        t.date :start_date
        t.date :end_date
      t.timestamps
    end
  end
end
