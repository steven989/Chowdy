class AddCustomerToFailedInvoice < ActiveRecord::Migration
  def change
    add_column :failed_invoices, :stripe_customer_id, :string
  end
end
