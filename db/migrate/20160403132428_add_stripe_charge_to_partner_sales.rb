class AddStripeChargeToPartnerSales < ActiveRecord::Migration
  def change
    add_column :partner_product_sales, :stripe_charge_id, :string
  end
end
