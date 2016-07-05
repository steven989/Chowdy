class AddExpiryDateToAnnouncements < ActiveRecord::Migration
  def change
    add_column :system_settings, :expiry_date, :date
  end
end
