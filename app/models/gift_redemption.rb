class GiftRedemption < ActiveRecord::Base
    belongs_to :gift
    belongs_to :customer, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
end
