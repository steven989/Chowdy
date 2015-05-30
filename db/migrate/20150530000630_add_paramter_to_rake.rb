class AddParamterToRake < ActiveRecord::Migration
  def change
    add_column :scheduled_tasks, :parameter_1, :string
    add_column :scheduled_tasks, :parameter_1_type, :string
    add_column :scheduled_tasks, :parameter_2, :string
    add_column :scheduled_tasks, :parameter_2_type, :string
    add_column :scheduled_tasks, :parameter_3, :string
    add_column :scheduled_tasks, :parameter_3_type, :string
    add_column :scheduled_tasks, :last_attempt_date, :datetime
  end
end
