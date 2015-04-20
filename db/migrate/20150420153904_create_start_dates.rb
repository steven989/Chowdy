class CreateStartDates < ActiveRecord::Migration
  def change
    create_table :start_dates do |t|
      t.date :start_date

      t.timestamps
    end
  end
end
