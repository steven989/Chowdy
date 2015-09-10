class UsersController < ApplicationController
    
    before_filter :require_login, only: :profile

    def create
        @user = User.new(user_params)
        if @user.save
            @user.update_attributes(email:@user.email.downcase)
            begin
                @user.log_activity("Online profile created")
            rescue => error
                puts error.message
            else
                puts '---------------------------------------------------'
            end
            auto_login(@user)
            redirect_to user_profile_path
        else
            @error_messages = @user.errors.full_messages.join(", ") if @user.errors.any?
            flash[:signup_error] = "Login could not be completed. #{@error_messages}"
            redirect_to create_customer_profile_path(@user.stripe_customer_id)
        end
    end

    def profile

        @current_user = current_user

        if @current_user.role == "admin"
            current_user.log_activity("admin dashboard")
            current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
            active_nonpaused_customers = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:current_pick_up_date)
            @current_customers_count = MealStatistic.retrieve("total_customer")
            @next_week_customers_count = MealStatistic.retrieve("total_customer_next_week")
            @monday_regular = MealStatistic.retrieve("monday_regular")
                @monday_regular_wandas = MealStatistic.retrieve("monday_regular_wandas")
                @monday_regular_coffee_bar = MealStatistic.retrieve("monday_regular_coffee_bar")
                @monday_regular_dekefir = MealStatistic.retrieve("monday_regular_dekefir")
                @monday_regular_gta_delivery = MealStatistic.retrieve("monday_regular_gta_delivery")
                
                @wandas_selected_beef_monday = MealStatistic.retrieve("wandas_selected_beef_monday")
                @wandas_selected_pork_monday = MealStatistic.retrieve("wandas_selected_pork_monday")
                @wandas_selected_poultry_monday = MealStatistic.retrieve("wandas_selected_poultry_monday")
                @wandas_selected_regular_monday = @wandas_selected_beef_monday.to_i + @wandas_selected_pork_monday.to_i + @wandas_selected_poultry_monday.to_i

                @coffee_bar_selected_beef_monday = MealStatistic.retrieve("coffee_bar_selected_beef_monday")
                @coffee_bar_selected_pork_monday = MealStatistic.retrieve("coffee_bar_selected_pork_monday")
                @coffee_bar_selected_poultry_monday = MealStatistic.retrieve("coffee_bar_selected_poultry_monday")
                @coffee_bar_selected_regular_monday = @coffee_bar_selected_beef_monday.to_i + @coffee_bar_selected_pork_monday.to_i + @coffee_bar_selected_poultry_monday.to_i

                @gta_selected_beef_monday = MealStatistic.retrieve("gta_selected_beef_monday")
                @gta_selected_pork_monday = MealStatistic.retrieve("gta_selected_pork_monday")
                @gta_selected_poultry_monday = MealStatistic.retrieve("gta_selected_poultry_monday")
                @gta_selected_regular_monday = @gta_selected_beef_monday.to_i + @gta_selected_pork_monday.to_i + @gta_selected_poultry_monday.to_i
            
            @monday_green = MealStatistic.retrieve("monday_green")
                @monday_green_wandas = MealStatistic.retrieve("monday_green_wandas")
                @monday_green_coffee_bar = MealStatistic.retrieve("monday_green_coffee_bar")
                @monday_green_dekefir = MealStatistic.retrieve("monday_green_dekefir")
                @monday_green_gta_delivery = MealStatistic.retrieve("monday_green_gta_delivery")

                @wandas_selected_green_1_monday = MealStatistic.retrieve("wandas_selected_green_1_monday")
                @wandas_selected_green_2_monday = MealStatistic.retrieve("wandas_selected_green_2_monday")
                @wandas_selected_green_monday = @wandas_selected_green_1_monday.to_i + @wandas_selected_green_2_monday.to_i

                @coffee_bar_selected_green_1_monday = MealStatistic.retrieve("coffee_bar_selected_green_1_monday")
                @coffee_bar_selected_green_2_monday = MealStatistic.retrieve("coffee_bar_selected_green_2_monday")
                @coffee_bar_selected_green_monday = @coffee_bar_selected_green_1_monday.to_i + @coffee_bar_selected_green_2_monday.to_i

                @gta_selected_green_1_monday = MealStatistic.retrieve("gta_selected_green_1_monday")
                @gta_selected_green_2_monday = MealStatistic.retrieve("gta_selected_green_2_monday")
                @gta_selected_green_monday = @gta_selected_green_1_monday.to_i + @gta_selected_green_2_monday.to_i

            @thursday_regular = MealStatistic.retrieve("thursday_regular")
                @thursday_regular_wandas = MealStatistic.retrieve("thursday_regular_wandas")
                @thursday_regular_coffee_bar = MealStatistic.retrieve("thursday_regular_coffee_bar")
                @thursday_regular_dekefir = MealStatistic.retrieve("thursday_regular_dekefir")
                @thursday_regular_gta_delivery = MealStatistic.retrieve("thursday_regular_gta_delivery")

                @wandas_selected_beef_thursday = MealStatistic.retrieve("wandas_selected_beef_thursday")
                @wandas_selected_pork_thursday = MealStatistic.retrieve("wandas_selected_pork_thursday")
                @wandas_selected_poultry_thursday = MealStatistic.retrieve("wandas_selected_poultry_thursday")
                @wandas_selected_regular_thursday = @wandas_selected_beef_thursday.to_i + @wandas_selected_pork_thursday.to_i + @wandas_selected_poultry_thursday.to_i

                @coffee_bar_selected_beef_thursday = MealStatistic.retrieve("coffee_bar_selected_beef_thursday")
                @coffee_bar_selected_pork_thursday = MealStatistic.retrieve("coffee_bar_selected_pork_thursday")
                @coffee_bar_selected_poultry_thursday = MealStatistic.retrieve("coffee_bar_selected_poultry_thursday")
                @coffee_bar_selected_regular_thursday = @coffee_bar_selected_beef_thursday.to_i + @coffee_bar_selected_pork_thursday.to_i + @coffee_bar_selected_poultry_thursday.to_i

                @gta_selected_beef_thursday = MealStatistic.retrieve("gta_selected_beef_thursday")
                @gta_selected_pork_thursday = MealStatistic.retrieve("gta_selected_pork_thursday")
                @gta_selected_poultry_thursday = MealStatistic.retrieve("gta_selected_poultry_thursday")
                @gta_selected_regular_thursday = @gta_selected_beef_thursday.to_i + @gta_selected_pork_thursday.to_i + @gta_selected_poultry_thursday.to_i


            @thursday_green = MealStatistic.retrieve("thursday_green")
                @thursday_green_wandas = MealStatistic.retrieve("thursday_green_wandas")
                @thursday_green_coffee_bar = MealStatistic.retrieve("thursday_green_coffee_bar")
                @thursday_green_dekefir = MealStatistic.retrieve("thursday_green_dekefir")
                @thursday_green_gta_delivery = MealStatistic.retrieve("thursday_green_gta_delivery")

                @wandas_selected_green_1_thursday = MealStatistic.retrieve("wandas_selected_green_1_thursday")
                @wandas_selected_green_2_thursday = MealStatistic.retrieve("wandas_selected_green_2_thursday")
                @wandas_selected_green_thursday = @wandas_selected_green_1_thursday.to_i + @wandas_selected_green_2_thursday.to_i

                @coffee_bar_selected_green_1_thursday = MealStatistic.retrieve("coffee_bar_selected_green_1_thursday")
                @coffee_bar_selected_green_2_thursday = MealStatistic.retrieve("coffee_bar_selected_green_2_thursday")
                @coffee_bar_selected_green_thursday = @coffee_bar_selected_green_1_thursday.to_i + @coffee_bar_selected_green_2_thursday.to_i

                @gta_selected_green_1_thursday = MealStatistic.retrieve("gta_selected_green_1_thursday")
                @gta_selected_green_2_thursday = MealStatistic.retrieve("gta_selected_green_2_thursday")
                @gta_selected_green_thursday = @gta_selected_green_1_thursday.to_i + @gta_selected_green_2_thursday.to_i

            @total_meals = MealStatistic.retrieve("total_meals")
            @total_meals_next = MealStatistic.retrieve("total_meals_next")

            @neg_adjustment_pork_monday = -MealStatistic.retrieve("neg_adjustment_pork_monday").to_i
            @neg_adjustment_beef_monday = -MealStatistic.retrieve("neg_adjustment_beef_monday").to_i
            @neg_adjustment_poultry_monday = -MealStatistic.retrieve("neg_adjustment_poultry_monday").to_i

            @neg_adjustment_pork_monday_wandas = -MealStatistic.retrieve("neg_adjustment_pork_monday_wandas").to_i
            @neg_adjustment_beef_monday_wandas = -MealStatistic.retrieve("neg_adjustment_beef_monday_wandas").to_i
            @neg_adjustment_poultry_monday_wandas = -MealStatistic.retrieve("neg_adjustment_poultry_monday_wandas").to_i

            @neg_adjustment_pork_monday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_pork_monday_coffee_bar").to_i
            @neg_adjustment_beef_monday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_beef_monday_coffee_bar").to_i
            @neg_adjustment_poultry_monday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_poultry_monday_coffee_bar").to_i

            @neg_adjustment_pork_monday_dekefir = -MealStatistic.retrieve("neg_adjustment_pork_monday_dekefir").to_i
            @neg_adjustment_beef_monday_dekefir = -MealStatistic.retrieve("neg_adjustment_beef_monday_dekefir").to_i
            @neg_adjustment_poultry_monday_dekefir = -MealStatistic.retrieve("neg_adjustment_poultry_monday_dekefir").to_i

            @neg_adjustment_pork_monday_gta_delivery = ""
            @neg_adjustment_beef_monday_gta_delivery = ""
            @neg_adjustment_poultry_monday_gta_delivery = ""

            @neg_adjustment_pork_thursday = -MealStatistic.retrieve("neg_adjustment_pork_thursday").to_i
            @neg_adjustment_beef_thursday = -MealStatistic.retrieve("neg_adjustment_beef_thursday").to_i
            @neg_adjustment_poultry_thursday = -MealStatistic.retrieve("neg_adjustment_poultry_thursday").to_i

            @neg_adjustment_pork_thursday_wandas = -MealStatistic.retrieve("neg_adjustment_pork_thursday_wandas").to_i
            @neg_adjustment_beef_thursday_wandas = -MealStatistic.retrieve("neg_adjustment_beef_thursday_wandas").to_i
            @neg_adjustment_poultry_thursday_wandas = -MealStatistic.retrieve("neg_adjustment_poultry_thursday_wandas").to_i

            @neg_adjustment_pork_thursday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_pork_thursday_coffee_bar").to_i
            @neg_adjustment_beef_thursday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_beef_thursday_coffee_bar").to_i
            @neg_adjustment_poultry_thursday_coffee_bar = -MealStatistic.retrieve("neg_adjustment_poultry_thursday_coffee_bar").to_i

            @neg_adjustment_pork_thursday_dekefir = -MealStatistic.retrieve("neg_adjustment_pork_thursday_dekefir").to_i
            @neg_adjustment_beef_thursday_dekefir = -MealStatistic.retrieve("neg_adjustment_beef_thursday_dekefir").to_i
            @neg_adjustment_poultry_thursday_dekefir = -MealStatistic.retrieve("neg_adjustment_poultry_thursday_dekefir").to_i

            @neg_adjustment_pork_thursday_gta_delivery = ""
            @neg_adjustment_beef_thursday_gta_delivery = ""
            @neg_adjustment_poultry_thursday_gta_delivery = ""

            active_nonpaused_customers_include_new_signups = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:[current_pick_up_date,StartDate.first.start_date.to_date])
            @customers_with_missing_info = active_nonpaused_customers_include_new_signups.where("((monday_pickup_hub is null or monday_pickup_hub ilike '%delivery%') and recurring_delivery is null) or ((thursday_pickup_hub is null or thursday_pickup_hub ilike '%delivery%') and recurring_delivery is null) or ((monday_delivery_hub is null or monday_delivery_hub ilike '%delivery%') and recurring_delivery is not null) or ((thursday_delivery_hub is null or thursday_delivery_hub ilike '%delivery%') and recurring_delivery is not null)")

            @all_failed_invoices = FailedInvoice.where(paid:false, closed:[false,nil])

            @customer_requesting_to_switch_to_pickup = StopQueue.where{(stop_type == "change_hub") & ((cancel_reason =~ "%wanda%") |(cancel_reason =~ "%coffee%")|(cancel_reason =~ "%dekefir%"))}.map{|s| s.stripe_customer_id}
            @deliveries = Customer.where{(active? >> ["Yes","yes"]) & (paused? >> [nil,"No","no"]) & ((recurring_delivery >> ["Yes","yes"])|((hub =~ "%delivery%") &(monday_pickup_hub == nil)))}

            feedback_limit = SystemSetting.where(setting:"feedback", setting_attribute:"display_limit").blank? ? 30 : SystemSetting.where(setting:"feedback", setting_attribute:"display_limit").take.setting_value.to_i
            @feedback = Feedback.all.limit(feedback_limit).order(created_at: :desc)

            @system_settings = SystemSetting.all.order(setting: :asc, setting_attribute: :asc)
            @scheduled_tasks = ScheduledTask.all

            @signup_timeseries = Customer.select('date_signed_up_for_recurring::date AS day, COUNT(*) as sign_ups').group('day').order('day asc').select{ |r| !r.day.nil?}.map {|r| [r.day.to_time.to_i*1000, r.sign_ups]}[-14..-1].to_a
            @cancel_timeseries = StopRequest.where(request_type:"cancel",end_date:nil).select('requested_date::date AS day, COUNT(*) as cancels').group('day').order('day asc').select{ |r| !r.day.nil?}.map {|r| [r.day.to_time.to_i*1000, r.cancels]}.to_a
            @cancel_curr_timeseries = StopQueue.where(stop_type:"cancel").select('created_at::date AS day, COUNT(*) as cancels').group('day').order('day asc').select{ |r| !r.day.nil?}.map {|r| [r.day.to_time.to_i*1000, r.cancels]}.to_a
            @cancel_curr_timeseries.each {|c| if @cancel_timeseries.select {|e| e[0] == c[0]}.length == 1; @cancel_timeseries.select {|e| e[0] == c[0]}[0][1] = @cancel_timeseries.select {|e| e[0] == c[0]}[0][1].to_i + c[1].to_i else  @cancel_timeseries.push c end} unless @cancel_curr_timeseries.blank?
            @cancel_timeseries = @cancel_timeseries.length >= 14 ? @cancel_timeseries[-14..-1].to_a : @cancel_timeseries[-@cancel_timeseries.length..-1].to_a
            @cancel_timeseries.sort_by! {|e| e[0]}

            @promotions = Promotion.all.order(created_at: :asc)

            @customer_column_names = []
            # Customer.columns.map {|c| c.name}


                @customer_column_names.push("email")
                @customer_column_names.push("name")
                @customer_column_names.push("active?")
                @customer_column_names.push("paused?")
                @customer_column_names.push("recurring_delivery")
                @customer_column_names.push("first_pick_up_date")
                @customer_column_names.push("next_pick_up_date")
                @customer_column_names.push("monday_pickup_hub")
                @customer_column_names.push("thursday_pickup_hub")
                @customer_column_names.push("monday_delivery_hub")
                @customer_column_names.push("thursday_delivery_hub")
                @customer_column_names.push("total_meals_per_week")
                @customer_column_names.push("regular_meals_on_monday")
                @customer_column_names.push("regular_meals_on_thursday")
                @customer_column_names.push("green_meals_on_monday")
                @customer_column_names.push("green_meals_on_thursday")
                @customer_column_names.push("referral")
                @customer_column_names.push("referral_code")
                @customer_column_names.push("matched_referrers_code")
                @customer_column_names.push("sponsored")
                @customer_column_names.push("pause_end_date")
                @customer_column_names.push("raw_green_input")
                @customer_column_names.push("hub")
                @customer_column_names.push("created_at")


            @all_customers = Customer.all.order(created_at: :desc)

        elsif @current_user.role == "chef"
            current_user.log_activity("chef dashboard")
            @menu = Menu.all.order(production_day: :asc)
        else

            @current_customer = current_user.customer
            @display_cancel = true
            @display_pause = true
            @display_restart = true
            @disable_sub_update = false
            @display_meal_selection = @current_customer.recurring_delivery.blank? ? false : true
            

            @selection_timing_exception_for_new_customers = (Date.today < @current_customer.first_pick_up_date && @current_customer.created_at > Chowdy::Application.closest_date(-1,3,@current_customer.first_pick_up_date) ) ? true : false  #cut off date is system setting, unless the customer signed up after Wednesday and it's before his first pick up
            cut_off_wday = @selection_timing_exception_for_new_customers ? ((Date.today.wday == 0 && DateTime.now.hour >= 14) ? SystemSetting.where(setting:'meal_selection', setting_attribute:'cut_off_week_day').take.setting_value.to_i : 7 ) : SystemSetting.where(setting:'meal_selection', setting_attribute:'cut_off_week_day').take.setting_value.to_i
            @cut_off_date = Chowdy::Application.wday(Date.today) == cut_off_wday ? Date.today : Chowdy::Application.closest_date(1,cut_off_wday)
            @display_production_day_1 = Chowdy::Application.wday(Date.today) <= cut_off_wday ? ( Chowdy::Application.wday(Date.today) == 7 ? Date.today : Chowdy::Application.closest_date(1,7)) : (Chowdy::Application.wday(Date.today) == 7 ? Chowdy::Application.closest_date(1,7) : Chowdy::Application.closest_date(2,7))
            @display_production_day_2 = Chowdy::Application.wday(Date.today) <= cut_off_wday ? ( Chowdy::Application.wday(Date.today) < 3 ? Chowdy::Application.closest_date(2,3) : Chowdy::Application.closest_date(1,3)) : (Chowdy::Application.wday(Date.today) < 3  ? Chowdy::Application.closest_date(3,3) : Chowdy::Application.closest_date(2,3))

            @monday_beef_selection_1_name = Menu.where(production_day:@display_production_day_1, meal_type:"Beef").take.meal_name unless Menu.where(production_day:@display_production_day_1, meal_type:"Beef").blank?
            @monday_pork_selection_1_name = Menu.where(production_day:@display_production_day_1, meal_type:"Pork").take.meal_name unless Menu.where(production_day:@display_production_day_1, meal_type:"Pork").blank?
            @monday_poultry_selection_1_name = Menu.where(production_day:@display_production_day_1, meal_type:"Poultry").take.meal_name unless Menu.where(production_day:@display_production_day_1, meal_type:"Poultry").blank?
            @monday_green_1_selection_1_name = Menu.where(production_day:@display_production_day_1, meal_type:"Green 1").take.meal_name unless Menu.where(production_day:@display_production_day_1, meal_type:"Green 1").blank?
            @monday_green_2_selection_1_name = Menu.where(production_day:@display_production_day_1, meal_type:"Green 2").take.meal_name unless Menu.where(production_day:@display_production_day_1, meal_type:"Green 2").blank?

            meal_selection_customer_monday = MealSelection.where(stripe_customer_id:@current_customer.stripe_customer_id,production_day:@display_production_day_1)

            @monday_beef_selection_1_number = meal_selection_customer_monday.blank? ? 0 : meal_selection_customer_monday.take.beef
            @monday_pork_selection_1_number = meal_selection_customer_monday.blank? ? 0 : meal_selection_customer_monday.take.pork
            @monday_poultry_selection_1_number = meal_selection_customer_monday.blank? ? 0 : meal_selection_customer_monday.take.poultry
            @monday_green_1_selection_1_number = meal_selection_customer_monday.blank? ? 0 : meal_selection_customer_monday.take.green_1
            @monday_green_2_selection_1_number = meal_selection_customer_monday.blank? ? 0 : meal_selection_customer_monday.take.green_2

            @thursday_beef_selection_1_name = Menu.where(production_day:@display_production_day_2, meal_type:"Beef").take.meal_name unless Menu.where(production_day:@display_production_day_2, meal_type:"Beef").blank?
            @thursday_pork_selection_1_name = Menu.where(production_day:@display_production_day_2, meal_type:"Pork").take.meal_name unless Menu.where(production_day:@display_production_day_2, meal_type:"Pork").blank?
            @thursday_poultry_selection_1_name = Menu.where(production_day:@display_production_day_2, meal_type:"Poultry").take.meal_name unless Menu.where(production_day:@display_production_day_2, meal_type:"Poultry").blank?
            @thursday_green_1_selection_1_name = Menu.where(production_day:@display_production_day_2, meal_type:"Green 1").take.meal_name unless Menu.where(production_day:@display_production_day_2, meal_type:"Green 1").blank?
            @thursday_green_2_selection_1_name = Menu.where(production_day:@display_production_day_2, meal_type:"Green 2").take.meal_name unless Menu.where(production_day:@display_production_day_2, meal_type:"Green 2").blank?

            meal_selection_customer_thursday = MealSelection.where(stripe_customer_id:@current_customer.stripe_customer_id,production_day:@display_production_day_2)

            @thursday_beef_selection_1_number = meal_selection_customer_thursday.blank? ? 0 : meal_selection_customer_thursday.take.beef
            @thursday_pork_selection_1_number = meal_selection_customer_thursday.blank? ? 0 : meal_selection_customer_thursday.take.pork
            @thursday_poultry_selection_1_number = meal_selection_customer_thursday.blank? ? 0 : meal_selection_customer_thursday.take.poultry
            @thursday_green_1_selection_1_number = meal_selection_customer_thursday.blank? ? 0 : meal_selection_customer_thursday.take.green_1
            @thursday_green_2_selection_1_number = meal_selection_customer_thursday.blank? ? 0 : meal_selection_customer_thursday.take.green_2


            current_user.log_activity("user accessing dashboard")
            @menu_date_sunday = Date.today.wday == 0 ? Chowdy::Application.closest_date(-2,7) : Chowdy::Application.closest_date(-1,7)
            @menu_date_wednesday = Chowdy::Application.closest_date(1,3,@menu_date_sunday)

            @beef_monday = Menu.where(production_day:@menu_date_sunday, meal_type:"Beef").take.meal_name unless Menu.where(production_day:@menu_date_sunday, meal_type:"Beef").blank?
            @pork_monday = Menu.where(production_day:@menu_date_sunday, meal_type:"Pork").take.meal_name unless Menu.where(production_day:@menu_date_sunday, meal_type:"Pork").blank?
            @poultry_monday = Menu.where(production_day:@menu_date_sunday, meal_type:"Poultry").take.meal_name unless Menu.where(production_day:@menu_date_sunday, meal_type:"Poultry").blank?
            @green_1_monday = Menu.where(production_day:@menu_date_sunday, meal_type:"Green 1").take.meal_name unless Menu.where(production_day:@menu_date_sunday, meal_type:"Green 1").blank?
            @green_2_monday = Menu.where(production_day:@menu_date_sunday, meal_type:"Green 2").take.meal_name unless Menu.where(production_day:@menu_date_sunday, meal_type:"Green 2").blank?


            @beef_thursday = Menu.where(production_day:@menu_date_wednesday, meal_type:"Beef").take.meal_name unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Beef").blank?
            @pork_thursday = Menu.where(production_day:@menu_date_wednesday, meal_type:"Pork").take.meal_name unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Pork").blank?
            @poultry_thursday = Menu.where(production_day:@menu_date_wednesday, meal_type:"Poultry").take.meal_name unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Poultry").blank?
            @green_1_thursday = Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 1").take.meal_name unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 1").blank?
            @green_2_thursday = Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 2").take.meal_name unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 2").blank?

            @beef_monday_id = Menu.where(production_day:@menu_date_sunday, meal_type:"Beef").take.id unless Menu.where(production_day:@menu_date_sunday, meal_type:"Beef").blank?
            @pork_monday_id = Menu.where(production_day:@menu_date_sunday, meal_type:"Pork").take.id unless Menu.where(production_day:@menu_date_sunday, meal_type:"Pork").blank?
            @poultry_monday_id = Menu.where(production_day:@menu_date_sunday, meal_type:"Poultry").take.id unless Menu.where(production_day:@menu_date_sunday, meal_type:"Poultry").blank?
            @green_1_monday_id = Menu.where(production_day:@menu_date_sunday, meal_type:"Green 1").take.id unless Menu.where(production_day:@menu_date_sunday, meal_type:"Green 1").blank?
            @green_2_monday_id = Menu.where(production_day:@menu_date_sunday, meal_type:"Green 2").take.id unless Menu.where(production_day:@menu_date_sunday, meal_type:"Green 2").blank?

            @beef_thursday_id = Menu.where(production_day:@menu_date_wednesday, meal_type:"Beef").take.id unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Beef").blank?
            @pork_thursday_id = Menu.where(production_day:@menu_date_wednesday, meal_type:"Pork").take.id unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Pork").blank?
            @poultry_thursday_id = Menu.where(production_day:@menu_date_wednesday, meal_type:"Poultry").take.id unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Poultry").blank?
            @green_1_thursday_id = Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 1").take.id unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 1").blank?
            @green_2_thursday_id = Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 2").take.id unless Menu.where(production_day:@menu_date_wednesday, meal_type:"Green 2").blank?


            @rated_menu_items = @current_customer.menu_ratings.where("menu_id is not null").order(created_at: :desc).limit(20).map{|mr| mr.menu_id }

            @current_pick_up_window_caption = (Date.today < @current_customer.first_pick_up_date) ? "Pick-up Window Next Week" : "Pick-up Window This Week"

            @number_of_referrals = Customer.where("matched_referrers_code ilike ?", @current_customer.referral_code).length
            @referral_dollars_earned = @number_of_referrals * 10

            @cancel_reasons =  SystemSetting.where(setting:"cancel_reason").map {|reason| reason.setting_value} 
            @hubs =  SystemSetting.where(setting:"hub", setting_attribute: ["hub_1","hub_2","hub_3"]).map {|hub| hub.setting_value} 
            
            unless @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take.blank?
                @requested_hub_to_change_to = @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take
                @hub_change_effective_date = @current_customer.stop_queues.where(stop_type:'change_hub').limit(1).take.start_date.strftime("%A %b %e")
            end

            @delivery_boundary_coordinates = SystemSetting.where(setting:"delivery_boundary", setting_attribute:"coordinates").take.setting_value
            @delivery_boundary_coordinates_gta = SystemSetting.where(setting:"delivery_boundary", setting_attribute:"gta_coordinates").take.setting_value

            if ["Yes","yes"].include? @current_customer.recurring_delivery
                monday_pickup_hub_match_string = "delivery"
                thursday_pickup_hub_match_string = "delivery"
            else
                monday_pickup_hub_match_string = case 
                                when !@current_customer.monday_pickup_hub.match(/wanda/i).nil?
                                    "wanda"
                                when !@current_customer.monday_pickup_hub.match(/dekefir/i).nil?
                                    "dekefir"
                                when !@current_customer.monday_pickup_hub.match(/coffee/i).nil? 
                                    "coffee"
                            end

                thursday_pickup_hub_match_string = case 
                                when !@current_customer.thursday_pickup_hub.match(/wanda/i).nil?
                                    "wanda"
                                when !@current_customer.thursday_pickup_hub.match(/dekefir/i).nil?
                                    "dekefir"
                                when !@current_customer.thursday_pickup_hub.match(/coffee/i).nil? 
                                    "coffee"
                            end

            end
         
            @pick_up_maps_info_text_monday =  case 
                            when !@current_customer.monday_pickup_hub.match(/wanda/i).nil?
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").blank?
                            when !@current_customer.monday_pickup_hub.match(/dekefir/i).nil?
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").blank?
                            when !@current_customer.monday_pickup_hub.match(/coffee/i).nil? 
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").blank?
                        end   

            @pick_up_maps_info_text_thursday =  case 
                            when !@current_customer.thursday_pickup_hub.match(/wanda/i).nil?
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").blank?
                            when !@current_customer.thursday_pickup_hub.match(/dekefir/i).nil?
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").blank?
                            when !@current_customer.thursday_pickup_hub.match(/coffee/i).nil? 
                                SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").blank?
                        end   

            if @current_customer.stop_queues.where(stop_type:"change_hub").length == 1

                next_week_hub_match_string = case 
                    when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/wanda/i).nil?
                        "wanda"
                    when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/dekefir/i).nil?
                        "dekefir"
                    when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/coffee/i).nil? 
                        "coffee"
                end


                pick_up_maps_info_text_next_week =  case 
                                when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/wanda/i).nil?
                                    SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_2_hours").blank?
                                when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/dekefir/i).nil?
                                    SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_3_hours").blank?
                                when !@current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.match(/coffee/i).nil? 
                                    SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").take.setting_value unless SystemSetting.where(setting:"hub", setting_attribute:"hub_1_hours").blank?
                            end   
            end

            # @address_to_show_on_dashboard = @current_customer.recurring_delivery.blank? ? @current_customer.hub.sub(/\(.+\)/, "").to_s : @current_customer.delivery_address.to_s
            @address_to_show_on_dashboard = @current_customer.recurring_delivery.blank? ?  ( @current_customer.monday_pickup_hub.blank? ?  ( @current_customer.stop_queues.where(stop_type:"change_hub").length == 1 ? [{location: @current_customer.stop_queues.where(stop_type:"change_hub").take.cancel_reason.to_s.sub(/\(.+\)/, "").to_s, hours:pick_up_maps_info_text_next_week}] : [{location: "", hours:""}] ) : (@current_customer.monday_pickup_hub == @current_customer.thursday_pickup_hub ? [{location:@current_customer.monday_pickup_hub.to_s.sub(/\(.+\)/, "").to_s, hours:@pick_up_maps_info_text_monday}] : [{location: @current_customer.monday_pickup_hub.to_s.sub(/\(.+\)/, "").to_s, hours:@pick_up_maps_info_text_monday},{location:@current_customer.thursday_pickup_hub.to_s.sub(/\(.+\)/, "").to_s, hours:@pick_up_maps_info_text_thursday}]) ) : [{location:@current_customer.delivery_address.to_s.sub(/\(.+\)/, "").to_s, hours:""}]

            @pick_up_text = @current_customer.monday_pickup_hub.blank? ? (@current_customer.stop_queues.where(stop_type: "change_hub").length == 1 ? @current_customer.stop_queues.where(stop_type: "change_hub").take.cancel_reason : "" ) : (@current_customer.monday_pickup_hub == @current_customer.thursday_pickup_hub ? @current_customer.monday_pickup_hub.to_s.gsub("\\","") : (@current_customer.monday_pickup_hub.to_s.gsub("\\","")+" on Monday and "+@current_customer.thursday_pickup_hub.to_s.gsub("\\","")+" on Thursday"))

            @show_pick_up_info_window = (@current_customer.recurring_delivery.blank? && ((!@current_customer.monday_pickup_hub.nil? && !@current_customer.thursday_pickup_hub.nil?) || (@current_customer.stop_queues.where(stop_type:"change_hub").length == 1))) ? true : false

            @announcements = SystemSetting.where{(setting == "announcement") & ((setting_attribute == "all") | (setting_attribute =~ "%#{monday_pickup_hub_match_string||= "xxx"}%")|(setting_attribute =~ "%#{thursday_pickup_hub_match_string ||= "xxx"}%") | (setting_attribute =~ "%#{next_week_hub_match_string ||= "xxx"}%"))}

            
            if @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.blank? || @selection_timing_exception_for_new_customers
                @change_effective_date = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.blank? ? nil : @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.start_date.strftime("%A %b %e")
                @total_meals = @current_customer.total_meals_per_week.to_i
                @total_green = @current_customer.number_of_green.to_i
                @monday_regular = @current_customer.regular_meals_on_monday.to_i
                @monday_green = @current_customer.green_meals_on_monday.to_i
                @thursday_regular = @current_customer.regular_meals_on_thursday.to_i
                @thursday_green = @current_customer.green_meals_on_thursday.to_i
                @no_selection_issue =  @current_customer.meal_selections.where(production_day:@display_production_day_1).blank? ? 0 : (@current_customer.total_meals_per_week.to_i - (@current_customer.meal_selections.where(production_day:@display_production_day_1).select{(pork + beef + poultry + green_1 + green_2).as(sum)}.first.sum + @current_customer.meal_selections.where(production_day:@display_production_day_2).select{(pork + beef + poultry + green_1 + green_2).as(sum)}.first.sum))
            else
                @change_effective_date = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.start_date.strftime("%A %b %e")
                @total_meals = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_meals.to_i
                @monday_regular = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_mon.to_i
                @monday_green = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_mon.to_i
                @thursday_regular = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_thu.to_i
                @thursday_green = @current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_thu.to_i
                @total_green = @monday_green + @thursday_green
                @no_selection_issue = @current_customer.meal_selections.where(production_day:@display_production_day_1).blank? ? 0 : ((@current_customer.meal_selections.where(production_day:@display_production_day_1).blank? || @current_customer.stop_queues.where(stop_type:'change_sub',start_date:Chowdy::Application.closest_date(1,1,@display_production_day_1)).blank?) ? 0 : (@current_customer.stop_queues.where(stop_type:'change_sub',start_date:Chowdy::Application.closest_date(1,1,@display_production_day_1)).take.updated_meals.to_i - @current_customer.meal_selections.where(production_day:@display_production_day_1).select{(pork + beef + poultry + green_1 + green_2).as(sum)}.first.sum - @current_customer.meal_selections.where(production_day:@display_production_day_2).select{(pork + beef + poultry + green_1 + green_2).as(sum)}.first.sum))


            end

            if @current_customer.active?.downcase == "yes" 
                if @current_customer.paused?.blank? || @current_customer.paused? == "No" || @current_customer.paused? == "no"
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                        if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'pause'
                            @current_status = "Active"
                            @sub_status = "Your account will be paused starting #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")} until #{(@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.end_date-1).strftime("%A %B %d, %Y")}. #{"Meal count change effective "+@change_effective_date+". " if @change_effective_date}#{"Hub change effective "+@hub_change_effective_date+"." if @requested_hub_to_change_to}"
                            @current_status_color = "text-success-lt"
                        elsif @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'cancel'
                            @current_status = "Active"
                            @sub_status = "Your subscription will be cancelled starting #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. You can restart subscription whenever you wish by clicking <b>Resume Subscription</b> button in the <b>Manage Subscription</b> tab."
                            @current_status_color = "text-success-lt"
                            @display_cancel = false
                        end
                    else
                        @current_status = "Active"
                        @current_status_color = "text-success-lt"
                        @sub_status = (@change_effective_date ? "Meal count change effective #{@change_effective_date}. " : "") +"#{@no_selection_issue < 0 ? 'You have chosen more meals for delivery than you have subscribed for. Please increase your subscription in the <a href="#changePlan" data-toggle="tab" class="url_seg">Manage Subscription</a> tab. If you do not do so, our system will automatically adjust for the difference upon delivery.' : (@no_selection_issue > 0 ? 'You have not yet selected all your meals for delivery next week. Please go to <a href="#meal_selection" data-toggle="tab" class="url_seg">Choose Meals</a> tab to choose your remaining meals' : '')}" + (@requested_hub_to_change_to ? "Hub change effective "+@hub_change_effective_date+"." : "")
                        @display_restart = false
                    end
                else
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                        if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'restart'
                            @current_status = "Paused"
                            @current_status_color = "text-warning-lt"
                            @sub_status = "Your subscription will resume on #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. "if @change_effective_date}#{@no_selection_issue < 0 ? 'You have chosen more meals for delivery than you have subscribed for. Please increase your subscription in the <a href="#changePlan" data-toggle="tab" class="url_seg">Manage Subscription</a> tab. If you do not do so, our system will automatically adjust for the difference upon delivery.' : (@no_selection_issue > 0 ? 'You have not yet selected all your meals for delivery next week. Please go to <a href="#meal_selection" data-toggle="tab" class="url_seg">Choose Meals</a> tab to choose your remaining meals' : '')}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                            @display_restart = false
                        elsif @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'pause'
                            @current_status = "Paused"
                            @current_status_color = "text-warning-lt"
                            @sub_status = "Your subscription will resume on #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.end_date.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. "if @change_effective_date}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                        elsif @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'cancel'
                            @current_status = "Paused"
                            @sub_status = "Your subscription will be cancelled starting #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. You can easily restart your subscription from the Manage Subscription tab whenever you want."
                            @current_status_color = "text-warning-lt"
                            @display_cancel = false
                        end
                    else
                        @pause_end = @current_customer.next_pick_up_date.to_date
                        @current_status = "Paused"
                        @current_status_color = "text-warning-lt"
                        @sub_status = "Your subscription will resume on #{@pause_end.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. " if @change_effective_date}#{@no_selection_issue < 0 ? 'You have chosen more meals for delivery than you have subscribed for. Please increase your subscription in the <a href="#changePlan" data-toggle="tab" class="url_seg">Manage Subscription</a> tab. If you do not do so, our system will automatically adjust for the difference upon delivery.' : (@no_selection_issue > 0 ? 'You have not yet selected all your meals for delivery next week. Please go to <a href="#meal_selection" data-toggle="tab" class="url_seg">Choose Meals</a> tab to choose your remaining meals' : '')}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                    end   
                    
                    
                end
            else
                if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).length > 0
                    if @current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.stop_type == 'restart'
                        @current_status = "Inactive"
                        @current_status_color = "text-danger-lt"
                        @display_pause = false
                        @sub_status = "Your subscription will resume on #{@current_customer.stop_queues.where(stop_type: ["cancel","pause","restart"]).order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")}. #{"Meal count change effective when you resume. " if @change_effective_date}#{@no_selection_issue < 0 ? 'You have chosen more meals for delivery than you have subscribed for. Please increase your subscription in the <a href="#changePlan" data-toggle="tab" class="url_seg">Manage Subscription</a> tab. If you do not do so, our system will automatically adjust for the difference upon delivery.' : (@no_selection_issue > 0 ? 'You have not yet selected all your meals for delivery next week. Please go to <a href="#meal_selection" data-toggle="tab" class="url_seg">Choose Meals</a> tab to choose your remaining meals' : '')}#{"Hub change effective when you resume." if @requested_hub_to_change_to}"
                        @display_restart = false
                    end
                else
                    @current_status = "Inactive"
                    @current_status_color = "text-danger-lt"
                    @sub_status = "You can restart your subscription by clicking the <b>Resume Subscription</b> button in the <a href='#changePlan' data-toggle='tab' class='url_seg'>Manage Subscription</a> tab #{'. Hub change effective when you resume.' if @requested_hub_to_change_to}"
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
            
            @delivery_boundary = @current_customer.delivery_boundary

            unless stripe_customer.subscriptions.data[0].blank?
                current_period_end = stripe_customer.subscriptions.data[0].current_period_end
                @next_billing_date = Time.at(current_period_end).to_datetime + 2.hours
            end
            if ["Inactive","Paused"].include? @current_status
                if @current_customer.recurring_delivery.blank?
                    @delivery_note = "You do not currently have scheduled delivery"
                    @delivery_button = "Request delivery"
                    @delivery_color_class = "warning"
                    @do_not_disable_delivery_button_initially = true unless (@current_customer.delivery_address.blank? || @current_customer.phone_number.blank?)
                else 
                    @delivery_note = "You have requested delivery but your account is on hold. Delivery will start when your subscription resumes."
                    @delivery_button = "Update delivery information"
                    @delivery_color_class = "warning"
                end
            else 
                if @current_customer.recurring_delivery.blank?
                    @delivery_note = "You do not currently have scheduled delivery"
                    @delivery_button = "Request delivery"
                    @delivery_color_class = "warning"                    
                    @do_not_disable_delivery_button_initially = true unless (@current_customer.delivery_address.blank? || @current_customer.phone_number.blank?)

                else 
                    @delivery_note = "You have scheduled delivery"
                    @delivery_button = "Update delivery information"
                    @delivery_color_class = "success"
                end
            end
            @delivery_address = @current_customer.delivery_address
            @phone_number = @current_customer.phone_number
            @note = @current_customer.special_delivery_instructions
            @delivery_boundary = @current_customer.delivery_boundary

            if [1,2,3,4].include? Date.today.wday
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
