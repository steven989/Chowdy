class CreateNutritionalInfos < ActiveRecord::Migration
  def change
    create_table :nutritional_infos do |t|
        t.integer :menu_id
        t.string :protein
        t.string :carb
        t.string :fat
        t.string :calories
        t.string :allergen


      t.timestamps null: false
    end
  end
end
