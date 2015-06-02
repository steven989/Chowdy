class AddMealPreferences < ActiveRecord::Migration
  def change
    add_column :customers, :no_beef, :boolean
    add_column :customers, :no_pork, :boolean
    add_column :customers, :no_poultry, :boolean
  end
end
