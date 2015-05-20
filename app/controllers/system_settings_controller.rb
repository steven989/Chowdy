class SystemSettingsController < ApplicationController

  def new
    @system_setting = SystemSetting.new

    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def create
    system_setting = SystemSetting.new(system_setting_params)
    system_setting.save
    redirect_to user_profile_path+"#system_settings"
  end

  def edit
    @system_setting = SystemSetting.find(params[:id])
    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def update
    system_setting = SystemSetting.find(params[:id])
    system_setting.update_attributes(system_setting_params)
    redirect_to user_profile_path+"#system_settings"
  end

  def destroy
    system_setting = SystemSetting.find(params[:id])
    system_setting.destroy
    redirect_to user_profile_path+"#system_settings"
  end

  private

  def system_setting_params
    params.require(:system_setting).permit(:setting, :setting_attribute, :setting_value)
  end
end
