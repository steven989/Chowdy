class CreateNoEmailCustomers < ActiveRecord::Migration
  def change
    create_table :no_email_customers do |t|
        t.string :stripe_customer_id
      t.timestamps null: false
    end
  end
end
