class CreateMealStatistics < ActiveRecord::Migration
  def change
    create_table :meal_statistics do |t|
        t.string :statistic
        t.string :statistic_type
        t.integer :value_integer
        t.string :value_string
        t.text :value_long_text

      t.timestamps null: false
    end
  end
end
