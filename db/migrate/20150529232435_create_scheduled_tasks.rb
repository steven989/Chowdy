class CreateScheduledTasks < ActiveRecord::Migration
  def change
    create_table :scheduled_tasks do |t|
        t.string :task_name
        t.integer :day_of_week
        t.integer :hour_of_day
        t.datetime :last_successful_run
      t.timestamps
    end
  end
end
