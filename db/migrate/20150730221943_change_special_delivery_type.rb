class ChangeSpecialDeliveryType < ActiveRecord::Migration
  def change
    change_column :customers, :special_delivery_instructions, :text
  end
end
