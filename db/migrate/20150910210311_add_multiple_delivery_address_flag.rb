class AddMultipleDeliveryAddressFlag < ActiveRecord::Migration
  def change
    add_column :customers, :different_delivery_address, :boolean
  end
end
