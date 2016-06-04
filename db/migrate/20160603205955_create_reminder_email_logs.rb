class CreateReminderEmailLogs < ActiveRecord::Migration
  def change
    create_table :reminder_email_logs do |t|
        t.string :stripe_customer_id
        t.date :date_reminder_sent
      t.timestamps null: false
    end
  end
end
