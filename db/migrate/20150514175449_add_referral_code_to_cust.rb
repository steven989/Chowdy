class AddReferralCodeToCust < ActiveRecord::Migration
  def change
    add_column :customers, :referral_code, :string
  end
end
