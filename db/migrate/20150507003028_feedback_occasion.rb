class FeedbackOccasion < ActiveRecord::Migration
  def change
    add_column :feedbacks, :occasion, :string
  end
end
