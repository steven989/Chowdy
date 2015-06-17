class AddMealTypeToMenu < ActiveRecord::Migration
  def change
    add_column :menus, :meal_type, :string
  end
end
