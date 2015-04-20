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

        Customer.create(
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
            next_pick_up_date: StartDate.first.start_dates
            )

        #add logic to split odd grean meal numbers

        render status:200

        #2) system to update the trial end date in stripe using the StartDate model
        

        #3) check for potential duplicate payment and send report

        #4) send confirmation email. Add a column to indicate that email has been sent

        #5) Any manual overrides required (referral, green meal count can't be parsed)

    end

    # def stripe_update #change customer account information through Stripe webhook
    #     #meal count (use customer.subscription.updated hook)
    #     #pause (use customer.subscription.updated hook)
    #     #active/inactive (use customer.subscription.deleted hook)
    # end

    def update #change customer account information from website
        #affect stripe
            #meal count (change plan in Stripe)      
            #pause (change trial date)
            #active/inactive (add/delete subscriptions; new subscriptions to have trial end date associated with it)
        #all database fields
    end

    def fail #failed charges
        #generate report (use charge.failed hook)
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

end
