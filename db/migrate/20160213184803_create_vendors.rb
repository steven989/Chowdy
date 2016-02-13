class CreateVendors < ActiveRecord::Migration
  def change
    create_table :vendors do |t|
        t.string :ext_vendor_id
        t.string :vendor_name
        t.text :vendor_description
        t.string :contact_name
        t.string :phone_number
        t.string :email_address
        t.string :alt_contact_name
        t.string :alt_phone_number
        t.string :alt_email_address
        t.string :vendor_address
        t.string :alt_vendor_address


      t.timestamps null: false
    end
  end
end
