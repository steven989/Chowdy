class GtaDeliveryField < ActiveRecord::Migration
  def change
    add_column :customers, :delivery_boundary, :string
  end
end
