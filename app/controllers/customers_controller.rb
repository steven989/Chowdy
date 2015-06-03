class CustomersController < ApplicationController

protect_from_forgery :except => :create
protect_from_forgery :except => :fail
protect_from_forgery :except => :payment

    def create #create customer account through Stripe webhook
        #0) Create an empty array of manual checks to flag
        manual_checks = []
        
        #1) create customer in the system
        customer_id = params[:data][:object][:id]
        green_number = params[:data][:object][:metadata][:green_meals_number] 
        customer_email = params[:data][:object][:email]
        customer_name = params[:data][:object][:metadata][:name]
        hub = params[:data][:object][:metadata][:hub].gsub(/\\/,"")
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

        unless Customer.where(stripe_customer_id:customer_id).length > 0 #this is so that Stripe doens't ceaselessly create new customers 

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
                next_pick_up_date: StartDate.first.start_date,
                date_signed_up_for_recurring: Time.now
                )

            customer.create_referral_code

            #assign hubs 
            if hub.match(/delivery/i).nil?
                customer.update_attributes(monday_pickup_hub:hub,thursday_pickup_hub:hub)
            end

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
                            if customer.id.odd? #this is to alternate whether Monday or Thursday gets more green
                                customer.update(green_meals_on_monday:green_number_to_use/2+1)
                                customer.update(green_meals_on_thursday:green_number_to_use/2)
                                monday_green = green_number_to_use/2+1
                                thursday_green = green_number_to_use/2
                            else
                                customer.update(green_meals_on_thursday:green_number_to_use/2+1)
                                customer.update(green_meals_on_monday:green_number_to_use/2)
                                thursday_green = green_number_to_use/2+1
                                monday_green = green_number_to_use/2
                            end
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
            
            begin
                stripe_customer = Stripe::Customer.retrieve(customer_id)
                stripe_subscription = stripe_customer.subscriptions.retrieve(subscription_id)
                stripe_subscription.trial_end = (StartDate.first.start_date+7.days+(23.5).hours).to_time.to_i
                stripe_subscription.prorate = false
                stripe_subscription.save
            rescue => error
                puts '---------------------------------------------------'
                puts "something went wrong trying to update Stripe subscription after customer is created"
                puts error.message
                puts '---------------------------------------------------' 
                CustomerMailer.rescued_error(customer,error.message).deliver
            end

            #3) check for referral and try to match up referrals
            
            unless referral.blank?

                if Customer.where(referral_code: referral.gsub(" ","").downcase).length == 1 #match code
                    referral_match = Customer.where(referral_code: referral.gsub(" ","").downcase)
                    
                    unless referral_match.take.stripe_subscription_id.blank?
                        #referrer discount
                        begin
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
                                elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                    stripe_referral_subscription_match.coupon = "referral bonus x 5"
                                else
                                    do_not_increment_referral = true
                                    CustomerMailer.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)").deliver
                                end

                            stripe_referral_subscription_match.prorate = false
                            if stripe_referral_subscription_match.save                
                                referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10) unless do_not_increment_referral
                            end
                        rescue => error
                            puts '---------------------------------------------------'
                            puts 'Something went wrong while updating Stripe referral code'
                            puts error.message
                            puts '---------------------------------------------------'
                            CustomerMailer.rescued_error(customer,error.message).deliver
                        end
                    end                
                    #referree discount

                    begin
                        stripe_subscription.coupon = "referral bonus"
                        stripe_subscription.prorate = false
                        if stripe_subscription.save
                            customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: customer.referral_bonus_referree.to_i + 10)
                        end
                    rescue => error
                            puts '---------------------------------------------------'
                            puts 'Something went wrong while updating Stripe referral code'
                            puts error.message
                            puts '---------------------------------------------------'
                            CustomerMailer.rescued_error(customer,error.message).deliver
                    end
                    referral_matched = true
                
                elsif Promotion.where(code: referral.gsub(" ",""),active:true).length == 1 #match promo code
                    promotion = Promotion.where(code: referral.gsub(" ","")).take
                        if promotion.immediate_refund
                            begin 
                                charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                                charge = Stripe::Charge.retrieve(charge_id)
                                charge.refunds.create(amount: promotion.amount_in_cents)
                            rescue => error
                                puts '---------------------------------------------------'
                                puts "Refund cannot be completed"
                                puts error.message
                                puts '---------------------------------------------------'
                                CustomerMailer.rescued_error(customer,error.message).deliver
                            else
                                promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
                            end
                        else 
                            stripe_subscription.coupon = promotion.stripe_coupon_id
                            stripe_subscription.prorate = false
                            if stripe_subscription.save
                                promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
                            end
                        end

                else #match name
                    referral_match = Customer.where("name ilike ?", referral.gsub(/\s$/,"").downcase)
                    if referral_match.length == 0
                        manual_checks.push("Referral typed in but no match")
                    elsif referral_match.length == 1
                        unless referral_match.take.stripe_subscription_id.blank?
                            #referrer discount
                            begin
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
                                elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                    stripe_referral_subscription_match.coupon = "referral bonus x 5"
                                else
                                    do_not_increment_referral = true
                                    CustomerMailer.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)").deliver
                                end

                            stripe_referral_subscription_match.prorate = false
                            if stripe_referral_subscription_match.save                
                                referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10)  unless do_not_increment_referral
                            end

                            rescue => error
                                CustomerMailer.rescued_error(customer,error.message).deliver
                            end
                        end

                        #referree discount
                        stripe_subscription.coupon = "referral bonus"
                        stripe_subscription.prorate = false
                        if stripe_subscription.save
                            customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: customer.referral_bonus_referree.to_i + 10)
                        end
                        referral_matched = true
                    elsif referral_match.length > 1
                        manual_checks.push("Referral matched multiple customers")
                    end
                end
            end

            #4) check for potential duplicate payment; automatically try to refund based on information
                # -1) check if there has been another customer created within the last two hours, based on
                        #email, #name
                        duplicate_match = Customer.where("email ilike ? and name ilike ? and total_meals_per_week = ? and id <> ? and created_at >= ?", customer_email, customer_name, meal_per_week,customer.id,3.hour.ago)
                        if Customer.where("email ilike ? and (name not ilike ? or total_meals_per_week <> ?) and id <> ?", customer_email, customer_name, meal_per_week,customer.id).length >= 1
                            manual_checks.push("New sign up email matches an existing customer but name or total meal count are different")
                        end
                # -2) refund payment and delete customer
                        if duplicate_match.length >= 1
                            begin 
                                charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                                charge = Stripe::Charge.retrieve(charge_id)
                                charge.refunds.create 
                            rescue => error
                                puts '---------------------------------------------------'
                                puts "Refund cannot be completed"
                                puts error.message
                                puts '---------------------------------------------------'
                                CustomerMailer.rescued_error(customer,error.message).deliver
                            else
                                customer.delete_with_stripe
                                CustomerMailer.duplicate_signup_email(first_name_email,customer_email).deliver
                            end
                        end
            #5) send confirmation email
                hub_email = hub.gsub(/\\/,"")
                start_date_email = StartDate.first.start_date
                first_name_email = customer_name.split(/\s/)[0].capitalize
                
                email_monday_regular = customer.regular_meals_on_monday
                email_thursday_regular = customer.regular_meals_on_thursday
                email_monday_green = customer.green_meals_on_monday
                email_thursday_green = customer.green_meals_on_thursday

                referral_name_email = referral.titlecase if referral_matched

                unless duplicate_match.length >= 1
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

        current_customer = current_user.customer
        
        if params[:id].downcase == "pause"
            
            end_date = params[:pause_date_picker]
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            unless end_date.blank?
                adjusted_pause_end_date = Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                if [2,3,4].include? Date.today.wday
                    adjusted_pause_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                else
                    adjusted_pause_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                end
                if (adjusted_pause_end_date > adjusted_pause_start_date) && (["Yes","yes"].include? current_customer.active?) && !(["Yes","yes"].include? current_customer.paused?)
                    current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                    current_customer.stop_queues.create(stop_type:'pause',associated_cutoff:associated_cutoff, end_date:adjusted_pause_end_date, start_date:adjusted_pause_start_date)
                end
            end

            redirect_to user_profile_path+"#changePlan"

        elsif params[:id].downcase == "cancel"    
            if [2,3,4].include? Date.today.wday
                adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_cancel_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            if ["Yes","yes"].include? current_customer.active?
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                current_customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:params[:cancel_reason])
            else
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
            end
            
            unless params[:feedback].blank?        
                if current_customer.feedbacks.create(feedback:params[:feedback], occasion:"cancel") 
                    CustomerMailer.feedback_received(current_customer).deliver
                end
            end
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "restart"
            if [2,3,4].include? Date.today.wday
                adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            
            if current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.blank?
                if ((["Yes","yes"].include? current_customer.active?) && (["Yes","yes"].include? current_customer.paused?)) || (current_customer.active?.blank? || (["No","no"].include? current_customer.active?))
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                end
            elsif ["pause","cancel"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ?", "pause", "cancel").destroy_all
            elsif ["restart"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                    current_customer.stop_queues.where("stop_type ilike ?", "restart").destroy_all
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
            end
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "change_card"
            begin
                current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)
                current_stripe_customer.source = params[:stripeToken]
                if current_stripe_customer.save
                    #attempt to pay back overdue invoices
                    if current_customer.failed_invoices.where("number_of_attempts > ? and paid = ?", 1, false).length > 0 
                        current_customer.failed_invoices.where("number_of_attempts > ? and paid = ?", 1, false).each do |failed_invoice| 
                            begin 
                                Stripe::Invoice.retrieve(failed_invoice.invoice_number).pay
                            rescue
                                puts "Card delined"
                            else
                                failed_invoice.update_attributes(paid:true,date_paid:Date.today)
                            end
                        end
                    end
                end
            rescue => error
                puts '---------------------------------------------------'
                puts "some error occured when customer tried to update credit card"
                puts error.message
                puts '---------------------------------------------------'
            end
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "email" 
            unless params[:email].blank?
                begin
                    current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)   
                    current_stripe_customer.email = params[:email]
                    if current_stripe_customer.save
                        current_customer.update(email:params[:email])
                        current_customer.user.update(email:params[:email])
                    end
                rescue => error
                    puts '---------------------------------------------------'
                    puts "some Stripe error occured when customer tried to change email"
                    puts error.message
                    puts '---------------------------------------------------'
                    CustomerMailer.rescued_error(current_customer,error.message).deliver
                end
                redirect_to user_profile_path+"#settings"
            end
        elsif params[:id].downcase == "hub" 
            if [2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday

            current_customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all
            current_customer.stop_queues.create(
                stop_type:'change_hub',
                associated_cutoff:associated_cutoff,
                start_date:adjusted_change_date,
                cancel_reason: params[:hub] #just using this field to capture any text value
            )
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "delivery" 
            _current_delivery = (["Yes","yes"].include? current_customer.recurring_delivery) ? true : false
            current_customer.update(phone_number:params[:phone_number], delivery_address:params[:delivery_address], special_delivery_instructions:params[:note], recurring_delivery:"yes")
            current_customer.update_attributes(monday_delivery_hub: "delivery") if current_customer.monday_delivery_hub.blank?
            current_customer.update_attributes(thursday_delivery_hub: "delivery") if current_customer.thursday_delivery_hub.blank?
            
            if _current_delivery
                CustomerMailer.stop_delivery_notice(current_customer, "Change delivery info").deliver
            else
                CustomerMailer.stop_delivery_notice(current_customer, "Start Delivery").deliver
            end
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "stop_delivery" 
            current_customer.update(recurring_delivery:nil)
            CustomerMailer.stop_delivery_notice(current_customer, "Stop Delivery").deliver
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "name" 
            current_customer.update(name:params[:name])
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "feedback"
            if current_customer.feedbacks.create(feedback:params[:feedback], occasion: 'regular') 
                CustomerMailer.feedback_received(current_customer).deliver
            end
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "change_subscription"
            total_updated_meals = params[:monday_reg_hidden].to_i + params[:monday_grn_hidden].to_i + params[:thursday_reg_hidden].to_i + params[:thursday_grn_hidden].to_i
            if [2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday

            if ([6,8,10,12,14].include?(total_updated_meals)) && (params[:thursday_grn_hidden].to_i + params[:monday_grn_hidden].to_i <= total_updated_meals)
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
            if (["Yes","yes"].include? current_customer.recurring_delivery) && (send_notification)
                CustomerMailer.stop_delivery_notice(current_customer, "Meal preference has changed").deliver
            end

            redirect_to user_profile_path+"#changePlan"
        end

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
        stripe_customer_id = params[:data][:object][:customer]
        invoice_number = params[:data][:object][:id]
        attempts = params[:data][:object][:attempt_count].to_i
        next_attempt = Time.at(params[:data][:object][:next_payment_attempt]).to_date
        invoice_amount = params[:data][:object][:lines][:data][0][:amount].to_i
        latest_attempt_date = Date.today
        invoice_date = Time.at(params[:data][:object][:date]).to_date

        existing_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take

        if existing_invoice.blank?
            if FailedInvoice.create(invoice_number: invoice_number, invoice_date:invoice_date, number_of_attempts:attempts, latest_attempt_date:latest_attempt_date, next_attempt:next_attempt, stripe_customer_id: stripe_customer_id, invoice_amount: invoice_amount)
                CustomerMailer.failed_invoice(FailedInvoice.where(invoice_number: invoice_number).take).deliver
            end
        else 
            existing_invoice.update_attributes(
                number_of_attempts:attempts, 
                latest_attempt_date:latest_attempt_date, 
                next_attempt:next_attempt, 
                invoice_amount: invoice_amount
                )
        end

        render nothing:true, status:200, content_type:'text/html'
    end

    def payment
        if params[:data][:object][:attempt_count].to_i > 1
            invoice_number = params[:data][:object][:id]
            failed_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take
            failed_invoice.update_attributes(paid:true,date_paid:Date.today) unless failed_invoice.blank?
        end
        render nothing:true, status:200, content_type:'text/html'
    end

    def resend_sign_up_link_form
        @customer = Customer.where(id:params[:id]).take
        respond_to do |format|
          format.html {
            render partial: 'resend_sign_up_link_form'
          }
        end  
    end

    def resend_sign_up_link
        customer = Customer.where(id:params[:id]).take
        target_email = params[:target_email].blank? ? customer.email : params[:target_email]
        CustomerMailer.resend_profile_link(target_email,customer).deliver
        redirect_to user_profile_path+"#customers"
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

    def admin
    end

end
