class ScheduledTasksController < ApplicationController

  def new
    @scheduled_task = ScheduledTask.new

    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def create
    scheduled_task = ScheduledTask.new(scheduled_task_params)
    scheduled_task.save
    redirect_to user_profile_path+"#system_settings"
  end

  def edit
    @scheduled_task = ScheduledTask.find(params[:id])
    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def run
    scheduled_task = ScheduledTask.find(params[:id])
    scheduled_task.delay.run
    redirect_to user_profile_path+"#system_settings"
  end

  def update
    scheduled_task = ScheduledTask.find(params[:id])
    scheduled_task.update_attributes(scheduled_task_params)
    redirect_to user_profile_path+"#system_settings"
  end

  def destroy
    scheduled_task = ScheduledTask.find(params[:id])
    scheduled_task.destroy
    redirect_to user_profile_path+"#system_settings"
  end

  private

  def scheduled_task_params
    params.require(:scheduled_task).permit(:task_name, :day_of_week, :hour_of_day, :last_attempt_date, :parameter_1, :parameter_1_type, :parameter_2, :parameter_2_type, :parameter_3, :parameter_3_type)
  end
end
