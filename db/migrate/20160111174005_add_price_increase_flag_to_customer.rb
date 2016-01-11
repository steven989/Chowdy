class AddPriceIncreaseFlagToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :price_increase_2015, :boolean
  end
end
