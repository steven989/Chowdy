class User < ActiveRecord::Base
  authenticates_with_sorcery!
  belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

  validates :password, confirmation: true, if: :new_user?
  validates :password_confirmation, presence: true, if: :new_user?

  validates :email, uniqueness: true

  private
  def new_user?
    new_record?
  end

end
