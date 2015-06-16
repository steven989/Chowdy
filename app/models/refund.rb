class Refund < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    attr_accessor :attach_to_next_invoice
end
