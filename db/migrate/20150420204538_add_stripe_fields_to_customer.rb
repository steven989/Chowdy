class AddStripeFieldsToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :stripe_customer_id, :string
    add_column :customers, :stripe_subscription_id, :string
  end
end
