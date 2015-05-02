class AddAmountToFailedInvoice < ActiveRecord::Migration
  def change
    add_column :failed_invoices, :invoice_amount, :integer
  end
end
