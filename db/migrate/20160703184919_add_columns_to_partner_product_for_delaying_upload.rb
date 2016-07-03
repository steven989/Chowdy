class AddColumnsToPartnerProductForDelayingUpload < ActiveRecord::Migration
  def change
    add_column :partner_products, :photos_processing, :boolean, null: false, default: false
    add_column :users, :photos_tmp, :string
  end
end
