class RemoveSomeColumnsFromPartnerProducts < ActiveRecord::Migration
  def change
    remove_column :partner_products, :photos_processing
    remove_column :users, :photos_tmp
  end
end
