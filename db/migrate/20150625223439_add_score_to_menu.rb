class AddScoreToMenu < ActiveRecord::Migration
  def change
    add_column :menus, :average_score, :float
    add_column :menus, :number_of_scores, :integer
  end
end
