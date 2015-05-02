class FailedInvoice < ActiveRecord::Base
    belongs_to :customer, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
end
