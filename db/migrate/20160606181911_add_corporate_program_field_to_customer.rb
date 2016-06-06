class AddCorporateProgramFieldToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :corporate, :boolean
    add_column :customers, :corporate_office, :string
  end
end
