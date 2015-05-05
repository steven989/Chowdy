namespace :customers do
    desc 'push start date to the next next Monday'
    task :push_start_date, [:number_of_weeks] => [:environment] do |t, args|        
        puts "Start date pushed to #{Chowdy::Application.closest_date(args[:number_of_weeks],1)}" if StartDate.first.update(start_date: Chowdy::Application.closest_date(args[:number_of_weeks],1))        
    end

    desc 'update status information for customers restarting after pause'
    task :restart_status => [:environment] do
        Customer.where(paused?: "yes", pause_end_date: [Chowdy::Application.closest_date(1,7), Chowdy::Application.closest_date(1,1)]).each do |customer|
            customer.update(paused?:'No', pause_end_date:nil,pause_cancel_request:nil)
        end
    end

    desc 'pause/cancel/restart customers'
    task :execute_pause_cancel_restart_queue, [:distance] => [:environment] do |t, args|
        if StopQueue.where(associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer
                if queue_item.stop_type == 'pause'
                    stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                    stripe_subscription.trial_end = queue_item.end_date.to_time.to_i
                    stripe_subscription.prorate = false
                    if stripe_subscription.save
                        current_customer.update(paused?:"yes", pause_end_date:queue_item.end_date-1, next_pick_up_date:queue_item.end_date)    
                        current_customer.stop_requests.create(request_type:'pause',start_date:queue_item.start_date, end_date:queue_item.end_date-1)
                        queue_item.destroy
                    end
                elsif queue_item.stop_type == 'cancel'
                    stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                    if stripe_subscription.delete
                        current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                        current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date)
                        queue_item.destroy
                    end
                elsif queue_item.stop_type == 'restart'
                    if current_customer.stripe_subscription_id.blank?
                        case current_customer.total_meals_per_week
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

                        start_date_update = queue_item.start_date
                        if Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:start_date_update.to_time.to_i)
                            new_subscription_id = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.all.data[0].id
                            current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", stripe_subscription_id: new_subscription_id,pause_cancel_request:nil) 
                            current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1)
                            queue_item.destroy
                        end
                    else 
                        start_date_update = queue_item.start_date
                        paused_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        paused_subscription.trial_end = start_date_update.to_time.to_i
                        paused_subscription.prorate = false
                        if paused_subscription.save
                            current_customer.update(next_pick_up_date:start_date_update, paused?:'No', pause_end_date:nil,pause_cancel_request:nil)
                            current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1)
                            queue_item.destroy
                        end
                    end
                end
            end
        else
            puts "No pause/cancel/restart request"
        end
    end




end