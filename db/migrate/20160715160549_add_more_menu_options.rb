class AddMoreMenuOptions < ActiveRecord::Migration
  def change
    add_column :meal_selections, :diet, :integer
    add_column :meal_selections, :chefs_special, :integer
  end
end
