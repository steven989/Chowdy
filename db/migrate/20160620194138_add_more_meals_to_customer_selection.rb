class AddMoreMealsToCustomerSelection < ActiveRecord::Migration
  def change
    add_column :meal_selections, :salad_bowl_1, :integer
    add_column :meal_selections, :salad_bowl_2, :integer
  end
end
