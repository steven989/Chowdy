class AddNewCustomerFlagToPromo < ActiveRecord::Migration
  def change
    add_column :promotions, :new_customer_only, :boolean
  end
end
