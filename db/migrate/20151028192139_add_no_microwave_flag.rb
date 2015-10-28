class AddNoMicrowaveFlag < ActiveRecord::Migration
  def change
    add_column :menus, :no_microwave, :boolean
  end
end
