class AddCombineDelivery < ActiveRecord::Migration
  def change
    add_column :customers, :split_delivery_with, :string
  end
end
