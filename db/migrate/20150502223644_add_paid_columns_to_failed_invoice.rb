class AddPaidColumnsToFailedInvoice < ActiveRecord::Migration
  def change
    add_column :failed_invoices, :paid, :boolean, default: false
    add_column :failed_invoices, :date_paid, :date
  end
end
