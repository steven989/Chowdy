
namespace :customers do
    desc 'push system start date to the next next Monday'
    task :push_start_date, [:number_of_weeks] => [:environment] do |t, args|        
        if StartDate.first.update(start_date: Chowdy::Application.closest_date(args[:number_of_weeks],1))        
            puts "Start date pushed to #{Chowdy::Application.closest_date(args[:number_of_weeks],1)}" 
            
        end
    end

    desc 'update status information for customers restarting after pause'
    task :restart_status => [:environment] do
        Customer.where(paused?: ["yes","Yes"], pause_end_date: [Chowdy::Application.closest_date(1,7), Chowdy::Application.closest_date(1,1)]).each do |customer|
            customer.update(paused?:nil, pause_end_date:nil,pause_cancel_request:nil,next_pick_up_date:Chowdy::Application.closest_date(1,1))
        end
    end

    desc 'update everyone\'s start date'
    task :update_individual_start_date, [:number_of_weeks] => [:environment] do |t, args|        
        Customer.where("next_pick_up_date = ?", Chowdy::Application.closest_date(-1,1)).each do |customer|
            customer.update_attributes(next_pick_up_date: Chowdy::Application.closest_date(args[:number_of_weeks],1))
        end
        SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.update_attributes(setting_value: Chowdy::Application.closest_date(args[:number_of_weeks],1).to_s)
    end


    desc 'email list of overdue bills to admin'
    task :email_customers_with_failed_invoices => [:environment] do
        CustomerMailer.failed_invoice_email.deliver
    end

    desc 'update meal count for dashboard display'
    task :update_meal_count => [:environment] do
        MealStatistic.all.each do |ms|
            result = Customer.meal_count(ms.statistic)
            if ms.statistic_type == "integer"
                ms.update_attributes(value_integer:result.to_i)
            elsif ms.statistic_type == "string"
                ms.update_attributes(value_string:result.to_s)
            elsif ms.statistic_type == "long_text"
                ms.update_attributes(value_long_text:result.to_s)
            end
        end
    end


    desc 'pause/cancel/restart customers'
    task :execute_pause_cancel_restart_queue, [:distance] => [:environment] do |t, args|
        if StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer
                if current_customer.stripe_subscription_id != nil
                    begin

                        if Date.today < current_customer.first_pick_up_date
                            raw_difference = queue_item.updated_meals - current_customer.total_meals_per_week
                            if raw_difference > 0
                                difference = raw_difference

                                Stripe::InvoiceItem.create(
                                    customer: current_customer.stripe_customer_id,
                                    amount: (difference * 6.99 * 1.13 * 100).round,
                                    currency: 'CAD',
                                    description: "First-week adjustment for #{difference} extra meals requested after sign up"
                                )

                                Stripe::Invoice.create(
                                    customer: current_customer.stripe_customer_id
                                )

                            elsif raw_difference < 0
                                
                                difference = raw_difference * -1
                                
                                charge_id = Stripe::Charge.all(customer:current_customer.stripe_customer_id,limit:1).data[0].id
                                charge = Stripe::Charge.retrieve(charge_id)
                                stripe_refund_response = charge.refunds.create(amount: (difference * 6.99 * 1.13 * 100).round)

                                newly_created_refund = Refund.create(
                                        stripe_customer_id: current_customer.stripe_customer_id, 
                                        refund_week:StartDate.first.start_date, 
                                        charge_week:Date.today,
                                        charge_id:charge_id, 
                                        meals_refunded: difference, 
                                        amount_refunded: (difference * 6.99 * 1.13 * 100).round, 
                                        refund_reason: "Subscription adjustment before first week", 
                                        stripe_refund_id: stripe_refund_response.id
                                )
                                newly_created_refund.internal_refund_id = newly_created_refund.id
                                newly_created_refund.save
                            end

                        end


                        case queue_item.updated_meals
                            when 6
                                meals_per_week = "6mealswk" 
                            when 8
                                meals_per_week = "8mealswk"
                            when 10
                                meals_per_week = "10mealswk"
                            when 12
                                meals_per_week = "12mealsweek"
                            when 14
                                meals_per_week = "14mealsweek"
                        end                    
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        _current_period_end = stripe_subscription.current_period_end
                        stripe_subscription.plan = meals_per_week
                        stripe_subscription.trial_end = _current_period_end
                        stripe_subscription.prorate = false
                        stripe_subscription.save
                    rescue => error
                        puts '---------------------------------------------------'
                        puts "something went wrong trying to change subscription during weekly task"
                        puts error.message
                        puts '---------------------------------------------------' 
                        CustomerMailer.rescued_error(current_customer,error.message).deliver
                    else
                        current_customer.update(
                            total_meals_per_week: queue_item.updated_meals, 
                            number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu,
                            regular_meals_on_monday: queue_item.updated_reg_mon, 
                            green_meals_on_monday: queue_item.updated_grn_mon,
                            regular_meals_on_thursday: queue_item.updated_reg_thu,
                            green_meals_on_thursday: queue_item.updated_grn_thu
                        )
                        queue_item.destroy
                    end
                else
                    current_customer.update(
                        total_meals_per_week: queue_item.updated_meals, 
                        number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu,
                        regular_meals_on_monday: queue_item.updated_reg_mon, 
                        green_meals_on_monday: queue_item.updated_grn_mon,
                        regular_meals_on_thursday: queue_item.updated_reg_thu,
                        green_meals_on_thursday: queue_item.updated_grn_thu
                    )
                end
            end
        end

        if StopQueue.where(stop_type: ["change_hub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_hub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                if queue_item.customer.update_attributes(hub:queue_item.cancel_reason,monday_pickup_hub:queue_item.cancel_reason,thursday_pickup_hub:queue_item.cancel_reason)
                    queue_item.destroy
                end
            end
        end

        if StopQueue.where(stop_type: ["cancel","pause","restart"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["cancel","pause","restart"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer
                if queue_item.stop_type == 'pause'

                    if current_customer.stripe_subscription_id.blank?
                        current_customer.update(paused?:"yes", pause_end_date:queue_item.end_date-1, next_pick_up_date:queue_item.end_date)
                        current_customer.stop_requests.create(request_type:'pause',start_date:queue_item.start_date, end_date:queue_item.end_date-1, requested_date: queue_item.created_at)
                        queue_item.destroy
                    else
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        stripe_subscription.trial_end = (queue_item.end_date + 23.9.hours).to_time.to_i
                        stripe_subscription.prorate = false
                        if stripe_subscription.save
                            current_customer.update(paused?:"yes", pause_end_date:queue_item.end_date-1, next_pick_up_date:queue_item.end_date)
                            current_customer.stop_requests.create(request_type:'pause',start_date:queue_item.start_date, end_date:queue_item.end_date-1, requested_date: queue_item.created_at)
                            queue_item.destroy
                        end
                    end

                elsif queue_item.stop_type == 'cancel'
                    if current_customer.stripe_subscription_id.blank?
                        current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                        current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date,cancel_reason:queue_item.cancel_reason, requested_date: queue_item.created_at)
                        queue_item.destroy                        
                    else
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        if stripe_subscription.delete
                            current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                            current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date,cancel_reason:queue_item.cancel_reason, requested_date: queue_item.created_at)
                            queue_item.destroy
                        end
                    end
                elsif queue_item.stop_type == 'restart'
                    if current_customer.stripe_subscription_id.blank?
                        start_date_update = queue_item.start_date
                        if current_customer.sponsored?
                            current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil,pause_cancel_request:nil) 
                            current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                            queue_item.destroy                            
                        else
                            current_customer_interval = current_customer.interval.blank? ? "week" : current_customer.interval
                            current_customer_interval_count = current_customer.interval_count.blank? ? 1 : current_customer.interval_count
                            meals_per_week = Subscription.where(weekly_meals:current_customer.total_meals_per_week, interval: current_customer_interval, interval_count:current_customer_interval_count).take.stripe_plan_id
                            
                            if Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:(start_date_update + 23.9.hours).to_time.to_i)
                                new_subscription_id = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.all.data[0].id
                                current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil, stripe_subscription_id: new_subscription_id,pause_cancel_request:nil) 
                                current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                                queue_item.destroy
                            end
                        end
                    else 
                        start_date_update = queue_item.start_date
                        paused_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        paused_subscription.trial_end = (start_date_update + 23.9.hours).to_time.to_i
                        paused_subscription.prorate = false
                        if paused_subscription.save
                            current_customer.update(next_pick_up_date:start_date_update, paused?:nil, pause_end_date:nil,pause_cancel_request:nil)
                            current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                            queue_item.destroy
                        end
                    end
                end
            end
        end
        #run this the second time
        if StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer
                if current_customer.stripe_subscription_id != nil
                    begin
                        case queue_item.updated_meals
                            when 6
                                meals_per_week = "6mealswk" 
                            when 8
                                meals_per_week = "8mealswk"
                            when 10
                                meals_per_week = "10mealswk"
                            when 12
                                meals_per_week = "12mealsweek"
                            when 14
                                meals_per_week = "14mealsweek"
                        end                    
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        _current_period_end = stripe_subscription.current_period_end
                        stripe_subscription.plan = meals_per_week
                        stripe_subscription.trial_end = _current_period_end
                        stripe_subscription.prorate = false
                        stripe_subscription.save
                    rescue => error
                        puts '---------------------------------------------------'
                        puts "something went wrong trying to change subscription during weekly task"
                        puts error.message
                        puts '---------------------------------------------------' 
                        CustomerMailer.rescued_error(current_customer,error.message).deliver
                    else
                        current_customer.update(
                            total_meals_per_week: queue_item.updated_meals, 
                            number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu,
                            regular_meals_on_monday: queue_item.updated_reg_mon, 
                            green_meals_on_monday: queue_item.updated_grn_mon,
                            regular_meals_on_thursday: queue_item.updated_reg_thu,
                            green_meals_on_thursday: queue_item.updated_grn_thu
                            )      
                    end

                else
                    current_customer.update(
                        total_meals_per_week: queue_item.updated_meals, 
                        number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu,
                        regular_meals_on_monday: queue_item.updated_reg_mon, 
                        green_meals_on_monday: queue_item.updated_grn_mon,
                        regular_meals_on_thursday: queue_item.updated_reg_thu,
                        green_meals_on_thursday: queue_item.updated_grn_thu
                        )                    
                end
                queue_item.destroy
            end
        end
    end




end

namespace :app do
    desc 'create admin'
    task :create_admin, [:email, :password] => [:environment] do |t, args|        
        user = User.new(email:args[:email], password:args[:password],password_confirmation:args[:password])
        if user.save
            user.update_attributes(role:"admin")
            puts "User successfully created"
        else
            puts "User could not be created"
        end
    end 

    desc 'Run scheduled tasks on the hour'
    task :run_scheduled_events => [:environment] do |t, args|        
        ScheduledTask.delay.run_all_tasks
    end 

    desc 'Take a daily snapshot of keys information that cannot be reconstructed later'
    task :take_daily_snapshot => [:environment] do 
        DailySnapshot.take_snapshot
    end 

    desc 'Email the customer as is to the admin'
    task :email_customer_list => [:environment] do 
        CustomerMailer.delay.send_customer_list
    end     

end
