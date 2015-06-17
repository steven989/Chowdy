class CreateMenus < ActiveRecord::Migration
  def change
    create_table :menus do |t|
        t.date :production_day
        t.string :meal_name
        t.string :protein
        t.string :carb
        t.string :veggie
        t.string :extra
        t.text   :notes
        t.boolean :dish

      t.timestamps null: false
    end
  end
end
