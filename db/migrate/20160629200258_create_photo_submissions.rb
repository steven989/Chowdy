class CreatePhotoSubmissions < ActiveRecord::Migration
  def change
    create_table :photo_submissions do |t|
        t.string :stripe_customer_id
        t.string :caption
        t.boolean :selected
        t.string :photo

      t.timestamps null: false
    end

    add_column :customers, :social_media_handles, :string
    add_column :customers, :photos_submitted, :integer
    add_column :customers, :meals_earned_from_photo_submission, :integer
  end
end
