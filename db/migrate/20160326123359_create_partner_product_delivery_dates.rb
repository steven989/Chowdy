class CreatePartnerProductDeliveryDates < ActiveRecord::Migration
  def change
    create_table :partner_product_delivery_dates do |t|
      t.date :delivery_date

      t.timestamps null: false
    end
  end
end
