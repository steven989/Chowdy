class AddPaidIndicatorToPhotoSubmissions < ActiveRecord::Migration
  def change
    add_column :photo_submissions, :paid, :boolean
  end
end
