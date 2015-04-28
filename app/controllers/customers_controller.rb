class CustomersController < ApplicationController

protect_from_forgery :except => :create

    def create #create customer account through Stripe webhook
        #0) Create an empty array of manual checks to flag
        manual_checks = []
        
        #1) create customer in the system
        customer_id = params[:data][:object][:id]
        green_number = params[:data][:object][:metadata][:green_meals_number] 
        customer_email = params[:data][:object][:email]
        customer_name = params[:data][:object][:metadata][:name]
        hub = params[:data][:object][:metadata][:hub]
        referral = params[:data][:object][:metadata][:referral]
        
        subscription_id = params[:data][:object][:subscriptions][:data][0][:id]
        plan = params[:data][:object][:subscriptions][:data][0][:plan][:id]
        case plan
            when "6mealswk" 
                meal_per_week = 6
            when "8mealswk"
                meal_per_week = 8
            when "10mealswk"
                meal_per_week = 10
            when "12mealsweek"
                meal_per_week = 12
            when "14mealsweek"
                meal_per_week = 14
        end

        customer = Customer.create(
            stripe_customer_id:customer_id, 
            raw_green_input:green_number, 
            email:customer_email, 
            name:customer_name,
            hub:hub,
            referral:referral,
            total_meals_per_week: meal_per_week,
            stripe_subscription_id: subscription_id,
            active?:"Yes",
            first_pick_up_date: StartDate.first.start_date,
            purchase:"Recurring",
            next_pick_up_date: StartDate.first.start_date
            )

        #add logic to split odd grean meal numbers
        raw_green_input = customer.raw_green_input
        begin
            Integer(raw_green_input)
        rescue
            if raw_green_input.nil? || raw_green_input == "null" || raw_green_input.blank?
                    monday_green = 0
                    thursday_green = 0
            else
                if raw_green_input.scan(/^all|\ball/i).length == 1 #if the string contains the text "all" at either the beginning of string or preceded by a white space
                    customer.update(number_of_green:meal_per_week)
                    customer.update(green_meals_on_monday:meal_per_week/2)
                    customer.update(green_meals_on_thursday:meal_per_week/2)
                    monday_green = meal_per_week/2
                    thursday_green = meal_per_week/2
                elsif raw_green_input.scan(/^none|\bnone/i).length == 1 #if the string contains the text "none" at either the beginning of string or preceded by a white space
                    customer.update(number_of_green:0)
                    monday_green = 0
                    thursday_green = 0
                elsif raw_green_input.scan(/\d+/).length == 1 #if the string contains one number
                    customer.update(number_of_green:raw_green_input.scan(/\d+/)[0].to_i)
                    green_number_to_use = [raw_green_input.scan(/\d+/)[0].to_i,meal_per_week].min
                    if green_number_to_use.odd?
                        customer.update(green_meals_on_monday:green_number_to_use/2+1)
                        customer.update(green_meals_on_thursday:green_number_to_use/2)
                        monday_green = green_number_to_use/2+1
                        thursday_green = green_number_to_use/2
                    else
                        customer.update(green_meals_on_monday:green_number_to_use/2)
                        customer.update(green_meals_on_thursday:green_number_to_use/2)                    
                        monday_green = green_number_to_use/2
                        thursday_green = green_number_to_use/2
                    end  
                else 
                    manual_checks.push("Check green meal input")
                    #send email for manual check
                    monday_green = 0
                    thursday_green = 0
                end
            end
        else 
            green_number_to_use = [raw_green_input.to_i,meal_per_week].min
            customer.update(number_of_green:green_number_to_use)
                if green_number_to_use.odd?
                    customer.update(green_meals_on_monday:green_number_to_use/2+1)
                    customer.update(green_meals_on_thursday:green_number_to_use/2)
                    monday_green = green_number_to_use/2+1
                    thursday_green = green_number_to_use/2
                else
                    customer.update(green_meals_on_monday:green_number_to_use/2)
                    customer.update(green_meals_on_thursday:green_number_to_use/2)                    
                    monday_green = green_number_to_use/2
                    thursday_green = green_number_to_use/2
                end
        end

        #logic to split meal count into Mondays and Thursdays
            if meal_per_week.odd?
                customer.update(regular_meals_on_monday:meal_per_week/2+1-monday_green)
                customer.update(regular_meals_on_thursday:meal_per_week/2-thursday_green)
            else 
                customer.update(regular_meals_on_monday:meal_per_week/2-monday_green)
                customer.update(regular_meals_on_thursday:meal_per_week/2-thursday_green)
            end

        #determine gender https://gender-api.com/
        #auto generate a unique customer ID (that's not a sequential number-based ID)
        #add an additional column to track Monday vs. Thursday hubs

        #2) system to update the trial end date in stripe using the StartDate model

        stripe_customer = Stripe::Customer.retrieve(customer_id)
        stripe_subscription = stripe_customer.subscriptions.retrieve(subscription_id)
        stripe_subscription.trial_end = (StartDate.first.start_date+7.days).to_time.to_i
        stripe_subscription.prorate = false
        stripe_subscription.save

        #3) check for referral and try to match up referrals
        unless referral.blank?
            referral_match = Customer.where("name ilike ?", referral.downcase)
            if referral_match.length == 0
                manual_checks.push("Referral typed in but no match")
            elsif referral_match.length == 1
                #referrer discount
                stripe_referral_match = Stripe::Customer.retrieve(referral_match.take.stripe_customer_id)
                stripe_referral_subscription_match = stripe_referral_match.subscriptions.retrieve(referral_match.take.stripe_subscription_id)
                
                    #check for existing coupons
                    if stripe_referral_subscription_match.discount.nil?
                        stripe_referral_subscription_match.coupon = "referral bonus"
                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus"
                        stripe_referral_subscription_match.coupon = "referral bonus x 2"
                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 2"
                        stripe_referral_subscription_match.coupon = "referral bonus x 3"
                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 3"
                        stripe_referral_subscription_match.coupon = "referral bonus x 4"
                    end

                stripe_referral_subscription_match.prorate = false
                stripe_referral_subscription_match.save                
                #referree discount
                stripe_subscription.coupon = "referral bonus"
                stripe_subscription.prorate = false
                stripe_subscription.save
                referral_matched = true
            elsif referral_match.length > 1
                manual_checks.push("Referral matched multiple customers")
            end
        end

        #4) check for potential duplicate payment; automatically try to refund based on information
            # -1) check if there has been another customer created within the last two hours, based on
                    #email, #name
                    duplicate_match = Customer.where("email ilike ? and name ilike ? and total_meals_per_week = ? and id <> ? and created_at >= ?", customer_email, customer_name, meal_per_week,customer.id,3.hour.ago)
                    if Customer.where("email ilike ?", customer_email).length >= 1
                        manual_checks.push("New sign up email matches an existing customer")
                    end
            # -2) refund payment and delete customer
                    if duplicate_match.length >= 1
                        charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                        charge = Stripe::Charge.retrieve(charge_id)
                        if charge.refunds.create 
                            customer.delete_with_stripe
                        end
                    end
        #5) send confirmation email. Add a column to indicate that email has been sent
            hub_email = hub.gsub(/\\/,"")
            start_date_email = StartDate.first.start_date
            first_name_email = customer_name.split(/\s/)[0].capitalize
            
            email_monday_regular = customer.regular_meals_on_monday
            email_thursday_regular = customer.regular_meals_on_thursday
            email_monday_green = customer.green_meals_on_monday
            email_thursday_green = customer.green_meals_on_thursday

            referral_name_email = referral.titlecase if referral_matched

            if duplicate_match.length >= 1
                CustomerMailer.duplicate_signup_email(first_name_email,customer_email).deliver
            else 
                CustomerMailer.confirmation_email(customer,hub_email,first_name_email,start_date_email,customer_email,meal_per_week,email_monday_regular,email_thursday_regular,email_monday_green,email_thursday_green,referral_name_email).deliver
            end

        #6) Send report with actions required
            if !hub.match(/delivery/i).nil?
                manual_checks.push("Delivery required")
            end
            #unmatched referrals (added)
            #green meal count can't be parsed (added) 
            #Delivery required --> auto send delivery information request email (added)
            #email matches an existing customer (added)

            if manual_checks.length >= 1 && duplicate_match.length < 1
                CustomerMailer.manual_check_for_signup(customer,manual_checks).deliver 
            end

            render nothing:true, status:200, content_type:'text/html'

    end

    def create_profile
        customer = Customer.where(stripe_customer_id:params[:id]).take
        if customer
            @user = User.new
            @stripe_customer_id = params[:id]
            @email = customer.email
        else
            #add a code to render something to the effect of customer not found
        end

    end

    # def stripe_update #change customer account information through Stripe webhook
    #     #meal count (use customer.subscription.updated hook)
    #     #pause (use customer.subscription.updated hook)
    #     #active/inactive (use customer.subscription.deleted hook)
    # end

    def update #change customer account information from website
        puts '---------------------------------------------------'
        puts params.inspect
        puts '---------------------------------------------------'

        current_customer = current_user.customer
        
        if params[:id].downcase == "pause"
            
            end_date = params[:end_date]
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            
            unless end_date.blank?
                adjusted_pause_end_date = Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                if [2,3,4].include? Date.today.wday
                    adjusted_pause_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                else
                    adjusted_pause_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                end
                if (adjusted_pause_end_date > adjusted_pause_start_date) && (["Yes","yes"].include? current_customer.active?) && !(["Yes","yes"].include? current_customer.paused?)
                    current_customer.stop_queues.destroy_all
                    current_customer.stop_queues.create(stop_type:'pause',associated_cutoff:associated_cutoff, end_date:adjusted_pause_end_date, start_date:adjusted_pause_start_date)
                end
            end

        elsif params[:id].downcase == "cancel"    
            if [2,3,4].include? Date.today.wday
                adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_cancel_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            if ["Yes","yes"].include? current_customer.active?
                current_customer.stop_queues.destroy_all
                current_customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date)
            else
                current_customer.stop_queues.destroy_all
            end
        elsif params[:id].downcase == "restart"    
            if [2,3,4].include? Date.today.wday
                adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            
            if current_customer.stop_queues.order(created_at: :desc).limit(1).take.blank?
                if ((["Yes","yes"].include? current_customer.active?) && (["Yes","yes"].include? current_customer.paused?)) || (current_customer.active?.blank? || (["No","no"].include? current_customer.active?))
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                end
            elsif ["pause","cancel"].include? current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type
                current_customer.stop_queues.destroy_all
            elsif ["restart"].include? current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type
                    current_customer.stop_queues.destroy_all
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)                
            end
        elsif params[:id].downcase == "change_card"    
            current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)
            current_stripe_customer.source = params[:stripeToken]
            current_stripe_customer.save
        elsif params[:id].downcase == "email" 
            current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)   
            current_stripe_customer.email = params[:email]
            if current_stripe_customer.save
                current_customer.update(email:params[:email])
                current_customer.user.update(email:params[:email])
            end
        elsif params[:id].downcase == "delivery" 
            current_customer.update(phone_number:params[:phone_number], delivery_address:params[:delivery_address], special_delivery_instructions:params[:note], recurring_delivery?:"Yes")
        elsif params[:id].downcase == "stop_delivery" 
            current_customer.update(recurring_delivery?:nil)
        elsif params[:id].downcase == "name" 
            current_customer.update(name:params[:name])
        elsif params[:id].downcase == "feedback"
            if current_customer.feedbacks.create(feedback:params[:feedback]) 
                CustomerMailer.feedback_received(current_customer).deliver
            end
        end

        redirect_to user_profile_path

        #affect stripe
            #meal count (change plan in Stripe)      
            #email (change in Stripe)
            #credit card
            #pause (change trial date)
            #active/inactive (add/delete subscriptions; new subscriptions to have trial end date associated with it)
        #all database fields
            #hub (Monday vs. Thursday)
            #name
            #meal split between Monday, Thursdan, regular, green; regular preference
            #delivery

    end

    def customer_sheet
        #create customer sheets 
    end

    def fail #failed charges
        #generate report (use charge.failed hook) for admin
        #auto email user
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

    def admin
    end

end
