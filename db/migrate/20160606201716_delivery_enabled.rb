class DeliveryEnabled < ActiveRecord::Migration
  def change
    add_column :customers, :monday_delivery_enabled, :boolean
    add_column :customers, :thursday_delivery_enabled, :boolean
  end
end
