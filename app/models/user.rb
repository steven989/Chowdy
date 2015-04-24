class User < ActiveRecord::Base
  authenticates_with_sorcery!
  belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

  validates :password, confirmation: true
  validates :password_confirmation, presence: true

  validates :email, uniqueness: true

end
