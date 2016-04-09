class ModifyChargeOnMarketplaceColumnToArray < ActiveRecord::Migration
  def change
    remove_column :partner_product_sales, :stripe_charge_id
    add_column :partner_product_sales, :stripe_charge_id, :string, default: [], array: true
  end
end
