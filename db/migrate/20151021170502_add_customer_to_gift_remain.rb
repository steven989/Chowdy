class AddCustomerToGiftRemain < ActiveRecord::Migration
  def change
    add_column :gift_remains, :stripe_customer_id, :string
  end
end
