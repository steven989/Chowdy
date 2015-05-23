class AddPauseToPromotion < ActiveRecord::Migration
  def change
    add_column :promotions, :pause, :boolean
  end
end
