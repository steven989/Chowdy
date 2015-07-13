class CreateStopQueueRecords < ActiveRecord::Migration
  def change
    create_table :stop_queue_records do |t|
        t.date     "associated_cutoff"
        t.string   "stop_type",          limit: 255
        t.string   "stripe_customer_id", limit: 255
        t.date     "end_date"
        t.date     "start_date"
        t.integer  "updated_meals"
        t.integer  "updated_reg_mon"
        t.integer  "updated_reg_thu"
        t.integer  "updated_grn_mon"
        t.integer  "updated_grn_thu"
        t.string   "cancel_reason",      limit: 255        
        t.datetime "queue_created_at"
        t.datetime "queue_updated_at"

      t.timestamps null: false
    end
  end
end
