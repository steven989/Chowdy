class ChangeColumnType < ActiveRecord::Migration
  def change
    remove_column :partner_products, :photos
    add_column :partner_products, :photos, :string, default: [], array: true
  end
end
