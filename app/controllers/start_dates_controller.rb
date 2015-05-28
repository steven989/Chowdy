class StartDatesController < ApplicationController
    def edit
        @start_date = StartDate.first
        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end
    end

    def update
       @start_date = StartDate.first
       @start_date.update_attributes(start_date: params[:start_date][:start_date]) 
       redirect_to user_profile_path+"#system_settings"
    end
end
