class AddFacebookEmailToUser < ActiveRecord::Migration
  def change
    add_column :users, :facebook_email, :string
  end
end
