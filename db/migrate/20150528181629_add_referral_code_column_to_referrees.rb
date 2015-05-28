class AddReferralCodeColumnToReferrees < ActiveRecord::Migration
  def change
    add_column :customers, :matched_referrers_code, :string
  end
end
