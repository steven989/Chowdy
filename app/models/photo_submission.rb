class PhotoSubmission < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

    mount_uploader :photo, PhotoSubmissionUploader 

end
