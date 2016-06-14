class CustomersController < ApplicationController

protect_from_forgery :except => :create
protect_from_forgery :except => :fail
protect_from_forgery :except => :payment

    def create #create customer account through Stripe webhook


        customer_id = params[:data][:object][:id]
        customer_email = params[:data][:object][:email].downcase

        if params[:data][:object][:subscriptions][:data]
            green_number = params[:data][:object][:metadata][:green_meals_number] 
            customer_name = params[:data][:object][:metadata][:name]
            hub = params[:data][:object][:metadata][:hub].gsub(/\\/,"")
            referral = params[:data][:object][:metadata][:referral]
            subscription_id = params[:data][:object][:subscriptions][:data][0][:id]
            plan = params[:data][:object][:subscriptions][:data][0][:plan][:id]

            Customer.delay.create_from_sign_up(customer_id,green_number,customer_email,customer_name,hub,referral,subscription_id,plan) 

        else
            Gift.delay.create_from_sign_up(customer_id,customer_email)

        end

        render nothing:true, status:200, content_type:'text/html'

    end

    def rate_menu_item
        current_customer = current_user.customer
        menu_id = params[:menu_id].to_i
        comment = params[:comment]
        rating = params[:rating].to_i


        respond_to do |format| 
            format.json {
                if params[:rating].blank?
                    render json: {result: false, message: "Rating cannot be blank"}
                else
                    menu = Menu.find(menu_id)

                    if menu.production_day > Date.today
                        render json: {result: false, message: "You cannot rate future meals"}
                    else 
                        menu.menu_ratings.where(stripe_customer_id: current_customer.stripe_customer_id).delete_all
                        rating_obj = menu.menu_ratings.new(comment:comment,rating:rating,stripe_customer_id:current_customer.stripe_customer_id)
                        if rating_obj.save
                            menu.delay.refresh_rating
                            render json: {result: true, message: "Rating saved"}
                        else
                            render json: {result: false, message: rating_obj.errors.full_messages.join(", ")}
                        end
                    end
                end
            }
        end
    end

    def create_profile
        customer = Customer.where(stripe_customer_id:params[:id]).take
        if customer
            if customer.user
                @user_exists = true
            else
                @user = User.new
                @stripe_customer_id = params[:id]
                @email = customer.email
            end
        else
            @customer_not_found = true
        end
    end

    def update #change customer account information from website

        current_customer = current_user.customer
 
        if params[:id].downcase == "pause"
            
            start_date = params[:pause_date_start_picker]
            end_date = params[:pause_date_picker]
            associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday

            if [1,2,3,4].include? Date.today.wday
                min_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                min_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end

            unless end_date.blank? || start_date.blank? 
                unless end_date.to_date < start_date.to_date + 7 || start_date.to_date < min_start_date
                    associated_cutoff = [associated_cutoff, Chowdy::Application.closest_date(-1,4,start_date.to_date)].max

                    adjusted_pause_end_date = end_date.to_date.wday == 1 ? end_date.to_date : Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                    adjusted_pause_start_date = [min_start_date,start_date.to_date].max #upcoming Monday

                    if (adjusted_pause_end_date > adjusted_pause_start_date) && (["Yes","yes"].include? current_customer.active?)
                        current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel","restart").destroy_all
                        current_customer.stop_queues.create(stop_type:'pause',associated_cutoff:associated_cutoff, end_date:adjusted_pause_end_date, start_date:adjusted_pause_start_date)
                        current_user.log_activity("Requested pause starting #{adjusted_pause_start_date.strftime("%Y-%m-%d")} until #{end_date}; the pause request will be processed on #{associated_cutoff.strftime("%Y-%m-%d")}")
                    end
                end
            end

            redirect_to user_profile_path+"#changePlan"

        elsif params[:id].downcase == "cancel"    
            if [1,2,3,4].include? Date.today.wday
                adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_cancel_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            
            if Date.today < current_customer.first_pick_up_date
                if Date.today == current_customer.created_at.to_date
                    associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday
                else
                    if [4,5,6,0].include?(Date.today.wday) 
                        associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                    else
                        associated_cutoff = Chowdy::Application.closest_date(2,4) #Thursday next week
                    end
                end
            else
                associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday
            end
            
            
            if ["Yes","yes"].include? current_customer.active?
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                current_customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:params[:cancel_reason])
                current_user.log_activity("Requested cancel")
            else
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
            end
            
            unless params[:feedback].blank?        
                current_customer.feedbacks.create(feedback:params[:feedback], occasion:"cancel") 
            end
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "restart"
            if [1,2,3,4].include? Date.today.wday
                adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end

            adjusted_restart_date = adjusted_restart_date == "2015-12-28".to_date ? Chowdy::Application.closest_date(1,1,adjusted_restart_date) : adjusted_restart_date #Christmas break for 2015
            
            associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday
            

                if current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.blank?
                    if ((["Yes","yes"].include? current_customer.active?) && (["Yes","yes"].include? current_customer.paused?)) || (current_customer.active?.blank? || (["No","no"].include? current_customer.active?))
                        current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                    end
                elsif ["pause","cancel"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                    if Date.today.between?("2015-12-18".to_date,"2015-12-24".to_date)
                        current_customer.stop_queues.where("stop_type ilike ?","cancel").destroy_all
                        current_user.log_activity("Restart requested")
                    else
                        current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ?", "pause", "cancel").destroy_all
                        current_user.log_activity("Restart requested")
                    end
                elsif ["restart"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                        current_customer.stop_queues.where("stop_type ilike ?", "restart").destroy_all
                        current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                        current_user.log_activity("Requested restart")
                end

            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "change_card"
            begin
                current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)
                current_stripe_customer.source = params[:stripeToken]
                current_stripe_customer.save
                #attempt to pay back overdue invoices
                decline_count = 0
                if current_customer.failed_invoices.where(paid:false).length > 0 
                    current_customer.failed_invoices.where(paid:false).each do |failed_invoice| 
                        begin 
                            stripe_invoice = Stripe::Invoice.retrieve(failed_invoice.invoice_number)
                            if stripe_invoice.closed
                                stripe_invoice.closed = false
                                stripe_invoice.save
                            end
                            stripe_invoice.pay
                        rescue
                            puts "Card declined"
                            decline_count += 1
                        else
                            failed_invoice.update_attributes(paid:true,closed:false,date_paid:Date.today)
                        end
                    end
                end
                if decline_count > 0
                    notice_status = "fail"
                    notice_message = "Card declined for one or more of your invoices"
                else
                    notice_status = "success"
                    notice_message = "Credit card updated"
                    current_user.log_activity("Credit card updated")
                end
            rescue => error
                puts '---------------------------------------------------'
                puts "some error occured when customer tried to update credit card"
                puts error.message
                puts '---------------------------------------------------'
                notice_status = "fail"
                notice_message = "Credit card could not be updated. #{error.message}"
            end
            flash[:status] = notice_status
            flash[:notice_customer_setting] = notice_message
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "email" 
            _old_email = current_customer.email
            unless params[:email].blank?
                begin
                    current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)   
                    current_stripe_customer.email = params[:email].downcase
                    if current_stripe_customer.save
                        current_customer.update_attributes(email:params[:email].downcase)
                        current_customer.user.update_attributes(email:params[:email].downcase)
                        if current_customer.errors.any? || current_customer.user.errors.any?
                            current_stripe_customer.email = _old_email
                            current_stripe_customer.save
                            current_customer.update(email:_old_email)
                            current_customer.user.update(email:_old_email)
                            notice_message = "Email could not be updated. #{current_customer.errors.full_messages.join(", ")} #{current_customer.user.errors.full_messages.join(", ")}"
                            notice_status = "fail"    
                        else 
                            notice_message = "Email updated"
                            notice_status = "success"  
                            current_user.log_activity("Email updated")
                        end
                    end
                rescue => error
                    puts '---------------------------------------------------'
                    puts "some Stripe error occured when customer tried to change email"
                    puts error.message
                    puts '---------------------------------------------------'
                    CustomerMailer.delay.rescued_error(current_customer,"Some Stripe error occured when customer tried to change email: "+error.message.inspect)
                    notice_message = "Email could not be updated. #{error.message}"
                    notice_status = "fail"
                end
                flash[:status] = notice_status
                flash[:notice_customer_setting] = notice_message
                redirect_to user_profile_path+"#settings"
            end
        elsif params[:id].downcase == "hub" 
            if [1,2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday

            current_customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all
            current_customer.stop_queues.create(
                stop_type:'change_hub',
                associated_cutoff:associated_cutoff,
                start_date:adjusted_change_date,
                cancel_reason: params[:hub] #just using this field to capture any text value
            )
            current_user.log_activity("Hub change requested")
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "delivery" 
            _current_delivery = (["Yes","yes"].include? current_customer.recurring_delivery) ? true : false

            monday_delivery_enabled = params[:monday_delivery_enabled].blank? ? false : true
            thursday_delivery_enabled = params[:thursday_delivery_enabled].blank? ? false : true

            current_customer.update(phone_number:params[:phone_number], delivery_address:params[:delivery_address],unit_number:params[:unit_number], special_delivery_instructions:params[:note], recurring_delivery:"yes", delivery_boundary:params[:boundary])
            current_customer.update_attributes(monday_delivery_hub: "delivery") if current_customer.monday_delivery_hub.blank?
            current_customer.update_attributes(thursday_delivery_hub: "delivery") if current_customer.thursday_delivery_hub.blank?
            current_customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all

            _monday_delivery_enabled = current_customer.monday_delivery_enabled?
            _thursday_delivery_enabled = current_customer.thursday_delivery_enabled?


            if (monday_delivery_enabled != _monday_delivery_enabled) || (thursday_delivery_enabled != _thursday_delivery_enabled)
                if monday_delivery_enabled && thursday_delivery_enabled
                    current_customer.balance_meals
                    current_customer.update(monday_delivery_enabled:monday_delivery_enabled,thursday_delivery_enabled:thursday_delivery_enabled)
                elsif monday_delivery_enabled && !thursday_delivery_enabled
                    current_customer.all_meals_on_day_1
                    current_customer.update(monday_delivery_enabled:monday_delivery_enabled,thursday_delivery_enabled:thursday_delivery_enabled)
                elsif thursday_delivery_enabled && !monday_delivery_enabled
                    current_customer.all_meals_on_day_2
                    current_customer.update(monday_delivery_enabled:monday_delivery_enabled,thursday_delivery_enabled:thursday_delivery_enabled)
                end
            else
                if (!_current_delivery) && (monday_delivery_enabled) && (!thursday_delivery_enabled) 
                    current_customer.all_meals_on_day_1
                    current_customer.update(monday_delivery_enabled:monday_delivery_enabled,thursday_delivery_enabled:thursday_delivery_enabled)
                elsif (!_current_delivery) && (!monday_delivery_enabled) && (thursday_delivery_enabled) 
                    current_customer.all_meals_on_day_2
                    current_customer.update(monday_delivery_enabled:monday_delivery_enabled,thursday_delivery_enabled:thursday_delivery_enabled)
                end
            end


            if _current_delivery
                if (Date.today.wday == 0 && current_customer.next_pick_up_date == Chowdy::Application.closest_date(1,1)) || (Date.today.wday == 1 && current_customer.next_pick_up_date == Date.today) || ([2,3].include?(Date.today.wday) && current_customer.next_pick_up_date == Chowdy::Application.closest_date(-1,1))
                    CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Change delivery info")
                    CustomerMailer.delay.stop_delivery_notice(current_customer, "Change delivery info")
                end
                current_user.log_activity("Updated delivery information")
            else
                if (Date.today.wday == 0 && current_customer.next_pick_up_date == Chowdy::Application.closest_date(1,1)) || (Date.today.wday == 1 && current_customer.next_pick_up_date == Date.today) || ([2,3].include?(Date.today.wday) && current_customer.next_pick_up_date == Chowdy::Application.closest_date(-1,1))
                    CustomerMailer.delay.stop_delivery_notice(current_customer, "Start Delivery")
                    CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Start Delivery")
                end
                flash[:status] = "warning"
                flash[:notice_delivery] = "Please select your meals in the <a href='#meal_selection' data-toggle='tab' class='url_seg'>Choose Meals</a> tab"
                current_user.log_activity("Start delivery requested")
            end
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "stop_delivery" 
            current_customer.update(recurring_delivery:nil)

            _monday_delivery_enabled = current_customer.monday_delivery_enabled?
            _thursday_delivery_enabled = current_customer.thursday_delivery_enabled?

            if !_monday_delivery_enabled || !_thursday_delivery_enabled
                current_customer.balance_meals
            end

            if (Date.today.wday == 0 && current_customer.next_pick_up_date == Chowdy::Application.closest_date(1,1)) || (Date.today.wday == 1 && current_customer.next_pick_up_date == Date.today) || ([2,3].include?(Date.today.wday) && current_customer.next_pick_up_date == Chowdy::Application.closest_date(-1,1))
                CustomerMailer.delay.stop_delivery_notice(current_customer, "Stop Delivery")
                CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Stop Delivery")
            end
            flash[:status] = "warning"
            flash[:notice_delivery] = "Your delivery has been stopped effective your next batch. If you have not selected a pick-up hub, please do so under <a href='#changePlan' data-toggle='tab' class='url_seg'>Manage Subscription</a> tab"
            current_user.log_activity("Stop delivery requested")
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "name" 
            current_customer.update_attributes(name:params[:name])

            if current_customer.errors.any?
                notice_status = "fail"
                notice_message = "Name could not be updated #{current_customers.errors.full_messages.join(", ")}"
            else
                notice_status = "success"
                notice_message = "Name updated"
                current_user.log_activity("Name updated")
            end

            flash[:status] = notice_status
            flash[:notice_customer_setting] = notice_message
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "feedback"
            current_customer.feedbacks.create(feedback:params[:feedback], occasion: 'regular') 
            flash[:status] = "success"
            flash[:notice_customer_setting] = "Feedback received. We appreciate it!"
            current_user.log_activity("Submitted feedback")
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "change_subscription"
            total_updated_meals = params[:monday_reg_hidden].to_i + params[:monday_grn_hidden].to_i + params[:thursday_reg_hidden].to_i + params[:thursday_grn_hidden].to_i
            if [1,2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday

            if (total_updated_meals.to_i >= 6) && (params[:thursday_grn_hidden].to_i + params[:monday_grn_hidden].to_i <= total_updated_meals)
                current_customer.stop_queues.where("stop_type ilike ?", "change_sub").destroy_all
                current_customer.stop_queues.create(
                    stop_type:'change_sub',
                    associated_cutoff:associated_cutoff,
                    updated_reg_mon:params[:monday_reg_hidden].to_i, 
                    updated_reg_thu:params[:thursday_reg_hidden].to_i, 
                    updated_grn_mon: params[:monday_grn_hidden].to_i, 
                    updated_grn_thu:params[:thursday_grn_hidden].to_i,
                    updated_meals:total_updated_meals, 
                    start_date:adjusted_change_date
                )
            end

            #meal preferences

            no_beef = params[:no_beef].blank? ? false : true
            no_pork = params[:no_pork].blank? ? false : true
            no_poultry = params[:no_poultry].blank? ? false : true
            send_notification = (no_beef != current_customer.no_beef) || (no_pork != current_customer.no_pork) || (no_poultry != current_customer.no_poultry)
            current_customer.update_attributes(no_beef:no_beef,no_pork:no_pork,no_poultry:no_poultry)
            if (["Yes","yes"].include? current_customer.recurring_delivery) && (send_notification) && ((Date.today.wday == 0 && current_customer.next_pick_up_date == Chowdy::Application.closest_date(1,1)) || (Date.today.wday == 1 && current_customer.next_pick_up_date == Date.today) || ([2,3].include?(Date.today.wday) && current_customer.next_pick_up_date == Chowdy::Application.closest_date(-1,1)))
                CustomerMailer.delay.stop_delivery_notice(current_customer, "Meal preference has changed")
                CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Meal preference has changed")
            end
            current_user.log_activity("Requested subscription change to #{total_updated_meals} meals per week, no beef: #{no_beef}, no poultry: #{no_poultry}, no pork: #{no_pork}")
            redirect_to user_profile_path+"#changePlan"
        end

    end

    def customer_sheet
        #create customer sheets 
    end

    def fail #failed charges
        Customer.delay.handle_failed_payment(params[:data][:object][:customer],params[:data][:object][:id],params[:data][:object][:attempt_count].to_i,(params[:data][:object][:next_payment_attempt].nil? ? nil : Time.at(params[:data][:object][:next_payment_attempt]).to_date),params[:data][:object][:lines][:data][0][:amount].to_i,Date.today,Time.at(params[:data][:object][:date]).to_date)
        render nothing:true, status:200, content_type:'text/html'
    end

    def payment
        Customer.delay.handle_payments(params[:data][:object][:id],params[:data][:object][:customer])

        render nothing:true, status:200, content_type:'text/html'
    end


    def resend_sign_up_link_form
        @customer = Customer.where(id:params[:id]).take
        @path = resend_sign_up_link_path(@customer)
        @form_title = "Resend link to create profile"
        respond_to do |format|
          format.html {
            render partial: 'resend_sign_up_link_form'
          }
        end  
    end

    def resend_confirmation_email_form
        @customer = Customer.where(id:params[:id]).take
        @path = resend_signup_confirmation_email_path(@customer)
        @form_title = "Resend sign up confirmation email"
        respond_to do |format|
          format.html {
            render partial: 'resend_sign_up_link_form'
          }
        end          
    end

    def resend_sign_up_link
        begin
            customer = Customer.where(id:params[:id]).take
            target_email = params[:target_email].blank? ? customer.email : params[:target_email]
            CustomerMailer.delay.resend_profile_link(target_email,customer)
        rescue => error 
            status = "fail"
            message = error.message
        else
            status = "success"
            message = ""
        end

        respond_to do |format|
          format.json {
            render json: {status:status, message:message}
          } 
        end    

    end

    def resend_signup_confirmation_email
        begin
            customer = Customer.where(id:params[:id]).take

            hub_email = customer.hub.gsub(/\\/,"")
            start_date_email = customer.first_pick_up_date
            first_name_email = customer.name.split(/\s/)[0].capitalize
            
            email_monday_regular = customer.regular_meals_on_monday
            email_thursday_regular = customer.regular_meals_on_thursday
            email_monday_green = customer.green_meals_on_monday
            email_thursday_green = customer.green_meals_on_thursday

            referral_name_email = nil
            meal_per_week = customer.total_meals_per_week
            customer_email = params[:target_email].blank? ? customer.email : params[:target_email]

            CustomerMailer.delay.confirmation_email(
                customer,
                hub_email,
                first_name_email,
                start_date_email,
                customer_email,
                meal_per_week,
                email_monday_regular,
                email_thursday_regular,
                email_monday_green,
                email_thursday_green,
                referral_name_email)
        rescue => error 
            status = "fail"
            message = error.message
        else
            status = "success"
            message = ""
        end 

        respond_to do |format|
          format.json {
            render json: {status:status, message:message}
          } 
        end 
    end

    def one_link_restart
        stripe_customer_id = params[:id]
        reminder_id = params[:reminder_id]
        @customer = Customer.where(stripe_customer_id:stripe_customer_id).take
        unless @customer.blank?
            if [1,2,3,4].include? Date.today.wday
                adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = [4].include?(Date.today.wday) ? Date.today : Chowdy::Application.closest_date(1,4) #upcoming Thursday
            
            if @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.blank?
                if ((["Yes","yes"].include? @customer.active?) && (["Yes","yes"].include? @customer.paused?)) || (@customer.active?.blank? || (["No","no"].include? @customer.active?))
                    @customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                end
            elsif ["pause","cancel"].include? @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ?", "pause", "cancel").destroy_all
            elsif ["restart"].include? @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                    @customer.stop_queues.where("stop_type ilike ?", "restart").destroy_all
                    @customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
            end

            ReminderEmailLog.find(reminder_id).update_attributes(restarted_with_direct_link:true) if ReminderEmailLog.find(reminder_id)

            if @customer.errors.any?
                flash[:status] = "fail"
                status = "fail"
                flash[:notice_customers] = "Restart request cannot be submitted: #{@customer.errors.full_messages.join(", ")}"    
                notice_customers = "Restart request cannot be submitted: #{@customer.errors.full_messages.join(", ")}"    
            else
                if @customer.user
                    @customer.user.log_activity("Customer requested restart through restart link")
                end
                flash[:status] = "success"
                status = "success"
                flash[:notice_customers] = "Restart request submitted"    
                notice_customers = "Restart request submitted"    
            end
        end

        if @customer.user
            auto_login(@customer.user)
        end
        
    end

    def add_to_do_not_email
        stripe_customer_id = params[:id]
        reminder_id = params[:reminder_id]
        @customer = Customer.where(stripe_customer_id:stripe_customer_id).take
        unless @customer.blank?
            if NoEmailCustomer.where(stripe_customer_id:stripe_customer_id).blank?
                NoEmailCustomer.create(stripe_customer_id:stripe_customer_id)
                ReminderEmailLog.find(reminder_id).update_attributes(requested_to_no_further_email:true) if ReminderEmailLog.find(reminder_id)
            end
        end
    end

    def resend_sign_up_link_customer_request
        email = params[:email].downcase
        customer = Customer.where(email:email).take
        target_email = params[:target_email].blank? ? customer.email : params[:target_email]
        CustomerMailer.delay.resend_profile_link(target_email,customer)
        
        flash[:status] = "success"
        flash[:login_error] = "We just emailed you the link to create your profile. If you don't get it shortly please email us at <a href='mailto:help@chowdy.ca?subject=Please%20email%20my%20sign%20up%20link%3A%20#{customer.stripe_customer_id}'>help@chowdy.ca</a>"
        redirect_to login_path
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

    def admin
    end

end
