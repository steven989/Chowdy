class AddSponsorship < ActiveRecord::Migration
  def change
    add_column :customers, :sponsored, :boolean
  end
end
