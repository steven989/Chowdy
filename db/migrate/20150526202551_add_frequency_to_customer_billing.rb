class AddFrequencyToCustomerBilling < ActiveRecord::Migration
  def change
    add_column :customers, :interval, :string
    add_column :customers, :interval_count, :integer
  end
end
