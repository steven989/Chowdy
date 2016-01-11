class AddPriceFlagToSubscription < ActiveRecord::Migration
  def change
    add_column :subscriptions, :price, :integer
  end
end
