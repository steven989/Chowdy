class AddPersonalMessageToGift < ActiveRecord::Migration
  def change
    add_column :gifts, :personal_message, :text
  end
end
