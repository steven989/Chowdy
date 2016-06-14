class AddMoreDetailsToReminderEmail < ActiveRecord::Migration
  def change
    add_column :reminder_email_logs, :discount, :integer
    add_column :reminder_email_logs, :restarted_with_direct_link, :boolean
    add_column :reminder_email_logs, :restarted_without_direct_link, :boolean
    add_column :reminder_email_logs, :requested_to_no_further_email, :boolean
  end
end
