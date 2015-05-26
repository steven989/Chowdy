class CreateSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions do |t|
        t.integer :weekly_meals
        t.string :stripe_plan_id
        t.string :interval
        t.integer :interval_count

      t.timestamps
    end
  end
end
