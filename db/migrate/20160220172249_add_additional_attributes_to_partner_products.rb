class AddAdditionalAttributesToPartnerProducts < ActiveRecord::Migration
  def change
    add_column :partner_products, :available, :boolean
    add_column :partner_products, :max_quantity, :integer
    add_column :partner_products, :quantity_available, :integer 
  end
end
