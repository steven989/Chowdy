class UsersController < ApplicationController
    
    before_filter :require_login, only: :profile

    def create
        @user = User.new(user_params)
        if @user.save
            auto_login(@user)
            redirect_to user_profile_path
        else
            redirect_to create_customer_profile_path(@user.stripe_customer_id)
        end
    end

    def profile

        @current_user = current_user
        if @current_user.role == "admin"
            current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
            active_nonpaused_customers = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:current_pick_up_date)
            @monday_regular = active_nonpaused_customers.sum(:regular_meals_on_monday).to_i
                @monday_regular_wandas = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").sum(:regular_meals_on_monday).to_i
                @monday_regular_coffee_bar = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").sum(:regular_meals_on_monday).to_i
                @monday_regular_dekefir = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").sum(:regular_meals_on_monday).to_i
            @monday_green = active_nonpaused_customers.sum(:green_meals_on_monday).to_i
                @monday_green_wandas = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").sum(:green_meals_on_monday).to_i
                @monday_green_coffee_bar = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").sum(:green_meals_on_monday).to_i
                @monday_green_dekefir = active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").sum(:green_meals_on_monday).to_i
            @thursday_regular = active_nonpaused_customers.sum(:regular_meals_on_thursday).to_i
                @thursday_regular_wandas = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").sum(:regular_meals_on_thursday).to_i
                @thursday_regular_coffee_bar = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i
                @thursday_regular_dekefir = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").sum(:regular_meals_on_thursday).to_i
            @thursday_green = active_nonpaused_customers.sum(:green_meals_on_thursday).to_i
                @thursday_green_wandas = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").sum(:green_meals_on_thursday).to_i
                @thursday_green_coffee_bar = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").sum(:green_meals_on_thursday).to_i
                @thursday_green_dekefir = active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").sum(:green_meals_on_thursday).to_i

            @total_meals = @monday_regular + @monday_green + @thursday_regular + @thursday_green

            # Pauses taking place next week
            puts @pause_next_week = StopQueue.where(stop_type:"pause").map {|q| q.customer.total_meals_per_week }.inject {|sum, x| sum + x}.to_i
            puts @cancel_next_week = StopQueue.where(stop_type:"cancel").map {|q| q.customer.total_meals_per_week }.inject {|sum, x| sum + x}.to_i
            puts @unpause_next_week = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:total_meals_per_week).to_i
            puts @restarts_next_week = StopQueue.where(stop_type:"restart").map {|q| q.customer.total_meals_per_week }.inject {|sum, x| sum + x}.to_i
            puts @meal_count_change = (StopQueue.where("stop_type ilike ? and stripe_customer_id not in (?)", "change_sub", StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}).sum(:updated_meals).to_i - StopQueue.where("stop_type ilike ? and stripe_customer_id not in (?)", "change_sub", StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}).map {|r| r.customer.total_meals_per_week}.inject {|sum, x| sum + x}).to_i
            puts @new_sign_ups = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).sum(:total_meals_per_week).to_i

            @total_meals_next = @total_meals - @pause_next_week - @cancel_next_week + @unpause_next_week + @restarts_next_week + @meal_count_change + @new_sign_ups 

            @customers_with_missing_info = active_nonpaused_customers.where("(monday_pickup_hub is null and recurring_delivery is null) or (thursday_pickup_hub is null and recurring_delivery is null) or (monday_delivery_hub is null and recurring_delivery is not null) or (thursday_delivery_hub is null and recurring_delivery is not null)")

            @all_failed_invoices = FailedInvoice.where(paid:false)

            @deliveries = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], recurring_delivery:["Yes","yes"])

            @system_settings = SystemSetting.all

            @signup_timeseries = Customer.select('date_signed_up_for_recurring::date AS day, COUNT(*) as sign_ups').group('day').map {|r| [r.day.to_time.to_i*1000, r.sign_ups]}
            @cancel_timeseries = StopRequest.where(request_type:"cancel",end_date:nil).select('requested_date::date AS day, COUNT(*) as cancels').group('day').map {|r| [r.day.to_time.to_i*1000, r.cancels]}
            @cancel_curr_timeseries = StopQueue.where(stop_type:"cancel").select('created_at::date AS day, COUNT(*) as cancels').group('day').map {|r| [r.day.to_time.to_i*1000, r.cancels]}
            @cancel_curr_timeseries.each {|c| @cancel_timeseries.push c}

        else
            @current_customer = current_user.customer
            @display_cancel = true
            @display_pause = true
            @display_restart = true
            @disable_sub_update = false

            @address_to_show_on_dashboard = @current_customer.recurring_delivery.blank? ? @current_customer.hub.sub(/\(.+\)/, "").to_s : @current_customer.delivery_address.to_s
            
            @number_of_referrals = Customer.where("referral ilike ?", @current_customer.name).length
            @referral_dollars_earned = @number_of_referrals * 10

            @cancel_reasons =  SystemSetting.where(setting:"cancel_reason").map {|reason| reason.setting_value} 
            @hubs =  SystemSetting.where(setting:"hub").map {|hub| hub.setting_value} 
            
            unless @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take.blank?
                @requested_hub_to_change_to = @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take
                @hub_change_effective_date = @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take.start_date.strftime("%A %b %e")
            end

            @delivery_boundary_coordinates = SystemSetting.where(setting:"delivery_boundary", setting_attribute:"coordinates").take.setting_value
            
            if @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.blank?
                @total_meals = @current_customer.total_meals_per_week.to_i
                @total_green = @current_customer.number_of_green.to_i
                @monday_regular = @current_customer.regular_meals_on_monday.to_i
                @monday_green = @current_customer.green_meals_on_monday.to_i
                @thursday_regular = @current_customer.regular_meals_on_thursday.to_i
                @thursday_green = @current_customer.green_meals_on_thursday.to_i
            else
                @change_effective_date = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.start_date.strftime("%A %b %e")
                @total_meals = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_meals.to_i
                @monday_regular = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_mon.to_i
                @monday_green = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_mon.to_i
                @thursday_regular = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_thu.to_i
                @thursday_green = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_thu.to_i
                @total_green = @monday_green + @thursday_green
            end

            if @current_customer.active?.downcase == "yes" 
                if @current_customer.paused?.blank? || @current_customer.paused? == "No" || @current_customer.paused? == "no"
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                        if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'pause'
                            @current_status = "Active"
                            @sub_status = "Your account will be paused starting #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")} until #{(@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.end_date-1).strftime("%A %B %d, %Y")}. #{"Meal count change effective "+@change_effective_date+". " if @change_effective_date}#{"Hub change effective "+@hub_change_effective_date+"." if @requested_hub_to_change_to}"
                        elsif @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'cancel'
                            @current_status = "Active"
                            @sub_status = "Your subscription will be cancelled starting #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}."
                            @display_cancel = false
                        end
                    else
                        @current_status = "Active"
                        @sub_status = (@change_effective_date ? "Meal count change effective #{@change_effective_date}. " : "") + (@requested_hub_to_change_to ? "Hub change effective "+@hub_change_effective_date+"." : "")
                        @display_restart = false
                    end
                else
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                        if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'restart'
                            @current_status = "Paused"
                            @sub_status = "Your subscription will resume on #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. "if @change_effective_date}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                            @display_restart = false
                        end
                    else
                        @pause_end = @current_customer.next_pick_up_date.to_date
                        @current_status = "Paused"
                        @sub_status = "Your subscription will resume on #{@pause_end.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. " if @change_effective_date}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                    end   
                    
                    
                end
            else
                if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'restart'
                        @current_status = "Inactive"
                        @display_pause = false
                        @sub_status = "Your subscription will resume on #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. " if @change_effective_date}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                        @display_restart = false
                    end
                else
                    @current_status = "Inactive"
                    @sub_status = "Hub change effective when you resume." if @requested_hub_to_change_to
                    @display_cancel = false
                    @display_pause = false
                    @disable_sub_update = true
                end   
            end

            @number_of_failed_invoices = @current_customer.failed_invoices.where(paid:false).length
            if @number_of_failed_invoices > 0
                @failed_weeks = []
                @current_customer.failed_invoices.where(paid:false).each do |failed_invoice|
                    @failed_weeks.push(Chowdy::Application.closest_date(-1,1,failed_invoice.invoice_date).strftime("%B %d"))
                end
            end

            stripe_customer = Stripe::Customer.retrieve(@current_customer.stripe_customer_id)
            card = stripe_customer.sources.all(:object => "card")
            @card_brand = card.data[0].brand
            @card_last4 = card.data[0].last4
            
            unless stripe_customer.subscriptions.data[0].blank?
                current_period_end = stripe_customer.subscriptions.data[0].current_period_end
                @next_billing_date = Time.at(current_period_end).to_datetime + 2.hours
            end
            if ["Inactive","Paused"].include? @current_status
                if @current_customer.recurring_delivery.blank?
                    @delivery_note = "You do not currently have scheduled delivery"
                    @delivery_button = "Request delivery"
                    @delivery_color_class = "warning"
                else 
                    @delivery_note = "You have requested delivery but your account is on hold"
                    @delivery_button = "Update delivery information"
                    @delivery_color_class = "warning"
                end
            else 
                if @current_customer.recurring_delivery.blank?
                    @delivery_note = "You do not currently have scheduled delivery"
                    @delivery_button = "Request delivery"
                    @delivery_color_class = "warning"
                else 
                    @delivery_note = "You have scheduled delivery"
                    @delivery_button = "Update delivery information"
                    @delivery_color_class = "success"
                end
            end
            @delivery_address = @current_customer.delivery_address
            @phone_number = @current_customer.phone_number
            @note = @current_customer.special_delivery_instructions

            if [2,3,4].include? Date.today.wday
                @earliest_pause_end_date = Chowdy::Application.closest_date(2,1)
            else
                @earliest_pause_end_date = Chowdy::Application.closest_date(3,1)
            end


        end
    end

    private

    def user_params
        params.require(:user).permit(:email,:password,:password_confirmation, :stripe_customer_id)
    end

    def require_login
        redirect_to login_path if !logged_in?
    end

end
