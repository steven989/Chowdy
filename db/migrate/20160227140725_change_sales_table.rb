class ChangeSalesTable < ActiveRecord::Migration
  def change
    remove_column :partner_product_sales, :partner_product_id
    remove_column :partner_product_sales, :quantity_ordered
    add_column :partner_product_sales, :total_amount_including_hst_in_cents, :integer
  end
end
