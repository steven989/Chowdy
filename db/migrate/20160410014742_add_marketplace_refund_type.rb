class AddMarketplaceRefundType < ActiveRecord::Migration
  def change
    add_column :partner_product_sale_refunds, :refund_type, :string
  end
end
