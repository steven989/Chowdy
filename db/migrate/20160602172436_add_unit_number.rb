class AddUnitNumber < ActiveRecord::Migration
  def change
    add_column :customers, :unit_number, :string
  end
end
