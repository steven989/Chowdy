class AddPositionToPartnerProducts < ActiveRecord::Migration
  def change
    add_column :partner_products, :position, :integer
  end
end
