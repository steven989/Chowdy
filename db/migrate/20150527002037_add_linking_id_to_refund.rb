class AddLinkingIdToRefund < ActiveRecord::Migration
  def change
    add_column :refunds, :internal_refund_id, :integer
  end
end
