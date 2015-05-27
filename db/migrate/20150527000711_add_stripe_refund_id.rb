class AddStripeRefundId < ActiveRecord::Migration
  def change
    add_column :refunds, :stripe_refund_id, :string
  end
end
