class AddAmountToPromotion < ActiveRecord::Migration
  def change
    add_column :promotions, :amount_in_cents, :integer
  end
end
