class AddRawGreenInput < ActiveRecord::Migration
  def change
    add_column :customers, :raw_green_input, :string
  end
end
