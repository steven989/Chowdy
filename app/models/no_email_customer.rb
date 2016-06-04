class NoEmailCustomer < ActiveRecord::Base
    has_one :customer, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
end
