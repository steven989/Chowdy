class CreateSystemSettings < ActiveRecord::Migration
  def change
    create_table :system_settings do |t|
        t.string :setting
        t.string :setting_attribute
        t.text :setting_value
      t.timestamps
    end
  end
end
