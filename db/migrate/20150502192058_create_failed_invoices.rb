class CreateFailedInvoices < ActiveRecord::Migration
  def change
    create_table :failed_invoices do |t|
        t.string :invoice_number
        t.date :invoice_date
        t.integer :number_of_attempts
        t.date :latest_attempt_date
        t.date :next_attempt
      t.timestamps
    end
  end
end
