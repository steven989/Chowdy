class CreateUserActivities < ActiveRecord::Migration
  def change
    create_table :user_activities do |t|
        t.integer :user_id
        t.string :activity_type

      t.timestamps null: false
    end
  end
end
