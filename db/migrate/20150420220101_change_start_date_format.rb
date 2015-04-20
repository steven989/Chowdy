class ChangeStartDateFormat < ActiveRecord::Migration
  def change
    change_column :start_dates, :start_date, :datetime 
  end
end
