class AddIdToSales < ActiveRecord::Migration
  def change
    add_column :partner_product_sales, :sale_id, :string
    add_column :partner_product_sales, :delivery_date, :date
  end
end
