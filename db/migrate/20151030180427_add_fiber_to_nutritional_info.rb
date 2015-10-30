class AddFiberToNutritionalInfo < ActiveRecord::Migration
  def change
    add_column :nutritional_infos, :fiber, :string
    add_column :nutritional_infos, :spicy, :boolean
  end
end
