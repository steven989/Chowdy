class AddImagesToPartnerProducts < ActiveRecord::Migration
  def change
    add_column :partner_products, :photos, :json
  end
end
