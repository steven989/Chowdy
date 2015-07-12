class AddClosedColumnToUnpaidInvoice < ActiveRecord::Migration
  def change
    add_column :failed_invoices, :closed, :boolean
  end
end
