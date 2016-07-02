class AddColumnToShowDateSelectedForPhotoSubmission < ActiveRecord::Migration
  def change
    add_column :photo_submissions, :date_selected, :date
  end
end
