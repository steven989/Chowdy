class AddDelayRelatedColumnToPhotoSubmission < ActiveRecord::Migration
  def change
    add_column :photo_submissions, :photo_processing, :boolean, null: false, default: false
  end
end
