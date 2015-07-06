class AddMealCountToMenu < ActiveRecord::Migration
  def change
    add_column :menus, :meal_count, :string
  end
end
