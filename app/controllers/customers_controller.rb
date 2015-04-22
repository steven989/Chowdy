class CustomersController < ApplicationController

protect_from_forgery :except => :create

    def create #create customer account through Stripe webhook
        #1) create customer in the system
        customer_id = params[:data][:object][:id]
        green_number = params[:data][:object][:metadata][:green_meals_number].to_i #create something here to throw an error if value cannot be converted to integer
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
            number_of_green:green_number, 
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
        

        #determine gender https://gender-api.com/
        #auto generate a unique customer ID (that's not a sequential number-based ID)
        #logic to split meal count into Mondays and Thursdays
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
                #send report for manual check
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
            elsif referral_match.length > 1
                #send report for manual check
            end
        end

        #4) check for potential duplicate payment; automatically try to refund based on information


        #5) send confirmation email. Add a column to indicate that email has been sent
            hub_email = hub.gsub(/\\/,"")
            start_date_email = StartDate.first.start_date
            first_name_email = customer_name.split(/\s/)[0].capitalize

            CustomerMailer.confirmation_email(hub_email,first_name_email,start_date_email,customer_email,meal_per_week).deliver
    
        #6) Send report with actions required
            #unmatched referrals
            #green meal count can't be parsed
            #duplicate payment that's not auto refunded
            #Delivery required --> auto send delivery information request email
            #Hub not determined
            #email matches an existing customer

    end

    def show
        #meal count
        #hub
        #regular vs. green, monday vs. thursday split
        #meal preferences
        #next billing date
        #credit card info
        #email
        #name
        #active status
        #delivery information
    end

    # def stripe_update #change customer account information through Stripe webhook
    #     #meal count (use customer.subscription.updated hook)
    #     #pause (use customer.subscription.updated hook)
    #     #active/inactive (use customer.subscription.deleted hook)
    # end

    def update #change customer account information from website
        #affect stripe
            #meal count (change plan in Stripe)      
            #credit card
            #email (change in Stripe)
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
