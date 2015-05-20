class ChangeDeliveryColumnName < ActiveRecord::Migration
  def change
    rename_column :customers, :recurring_delivery?, :recurring_delivery
  end
end
