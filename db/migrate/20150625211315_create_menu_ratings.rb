class CreateMenuRatings < ActiveRecord::Migration
  def change
    create_table :menu_ratings do |t|
        t.integer :menu_id
        t.string  :stripe_customer_id
        t.integer :rating
        t.text    :comment

      t.timestamps null: false
    end
  end
end
