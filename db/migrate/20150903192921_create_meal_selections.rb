class CreateMealSelections < ActiveRecord::Migration
  def change
    create_table :meal_selections do |t|
        t.string :stripe_customer_id
        t.date :production_day
        t.integer :pork
        t.integer :beef
        t.integer :poultry
        t.integer :green_1
        t.integer :green_2

      t.timestamps null: false
    end
  end
end
