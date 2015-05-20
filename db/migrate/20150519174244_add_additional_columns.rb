class AddAdditionalColumns < ActiveRecord::Migration
  def change
    add_column :customers, :monday_pickup_hub, :string
    add_column :customers, :thursday_pickup_hub, :string
    add_column :customers, :monday_delivery_hub, :string
    add_column :customers, :thursday_delivery_hub, :string
  end
end
