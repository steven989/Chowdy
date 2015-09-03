class ExtraIceIndicator < ActiveRecord::Migration
  def change
    add_column :customers, :extra_ice, :boolean
  end
end
