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
    if system_setting.save
      flash[:status] = "success"
      flash[:notice_system_settings] = "System setting created"
    else
      flash[:status] = "fail"
      flash[:notice_system_settings] = "System setting could not be created: #{system_setting.errors.full_messages.join(", ")}"
    end
    redirect_to user_profile_path+"#system_settings"
  end

  def edit
    @system_setting = SystemSetting.find(params[:id])
    @announcement = @system_setting.setting.downcase == "announcement"
    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def update
    system_setting = SystemSetting.find(params[:id])
    system_setting.update_attributes(system_setting_params)

    if system_setting.errors.any?
      flash[:status] = "fail"
      flash[:notice_system_settings] = "System setting could not be update: #{system_setting.errors.full_messages.join(", ")}"
    else
      flash[:status] = "success"
      flash[:notice_system_settings] = "System setting updated"
    end

    redirect_to user_profile_path+"#system_settings"
  end

  def new_announcement
    @hubs =  SystemSetting.where(setting:"hub", setting_attribute: ["hub_1","hub_2","hub_3","hub_5","hub_6"]).map {|hub| hub.setting_value} 
    @hubs.push("GTA delivery")
    @hubs.push("Downtown delivery")
    @hubs.push("$6.99 Customers")
    @system_setting = SystemSetting.new
    respond_to do |format|
      format.html {
        render partial: 'new_announcement_form'
      }
    end    
  end

  def create_announcement

    @scope = params[:system_setting][:setting_attribute].blank? ? "all" : params[:system_setting][:setting_attribute]
    expiry_date = params[:system_setting][:expiry_date].blank? ? nil : params[:system_setting][:expiry_date].to_date
    @system_setting = SystemSetting.new(setting:"announcement", setting_attribute:@scope, setting_value: params[:system_setting][:setting_value],expiry_date:expiry_date)
    if @system_setting.save
      flash[:status] = "success"
      flash[:notice_system_settings] = "Announcement created for #{@scope} customers"
    else
      flash[:status] = "fail"
      flash[:notice_system_settings] = "Announcement could not be created: #{@system_setting.errors.full_messages.join(", ")}"
    end

    redirect_to user_profile_path+"#system_settings"
  end

  def destroy
    system_setting = SystemSetting.find(params[:id])
    if system_setting.destroy
      flash[:status] = "success"
      flash[:notice_system_settings] = "System setting deleted"
    else
      flash[:status] = "fail"
      flash[:notice_system_settings] = "System setting could not be deleted: #{system_setting.errors.full_messages.join(", ")}"
    end

    redirect_to user_profile_path+"#system_settings"
  end

  private

  def system_setting_params
    params.require(:system_setting).permit(:setting, :setting_attribute, :setting_value, :expiry_date)
  end
end
