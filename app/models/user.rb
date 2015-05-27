class User < ActiveRecord::Base
  authenticates_with_sorcery!
  belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

  validates :password, confirmation: true, if: :new_user?, on: :create
  validates :password_confirmation, presence: true, if: :new_user?, on: :create

  validates :email, uniqueness: true

  authenticates_with_sorcery! do |config|
    config.authentications_class = Authentication
  end

  has_many :authentications, :dependent => :destroy
  accepts_nested_attributes_for :authentications

  private
  def new_user?
    new_record?
  end

end
