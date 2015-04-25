class CreateFeedbacks < ActiveRecord::Migration
  def change
    create_table :feedbacks do |t|
        t.string :stripe_customer_id
        t.text :feedback
      t.timestamps
    end
  end
end
