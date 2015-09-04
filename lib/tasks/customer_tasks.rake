
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

    desc 'look for anomalies in the customer data'
    task :scan_customer_data_anomalies => [:environment] do
        anomaly_array = []
        active_customers = Customer.where(active?: ["yes","Yes"])

        #negative meal counts
        negative_meal_count_customers = Customer.where{(active? >> ["yes","Yes"]) & ((regular_meals_on_monday < 0) | (green_meals_on_monday < 0 )| (regular_meals_on_thursday < 0) | (green_meals_on_thursday < 0))}
        negative_meal_count_customers.each {|c| anomaly_array.push([c,"negative meal count"]) }

        if anomaly_array.length > 0 
            CustomerMailer.delay.anomaly_report(anomaly_array)
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

    desc 'automatically increase or reduce meal selection above or below the number of meals subscribed'
    task :adjust_meal_selection_to_match_subscription => [:environment] do
        week = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        production_day_1 = Chowdy::Application.closest_date(-1,7,week)
        production_day_2 = Chowdy::Application.closest_date(1,3,week)
        mismatched_rows = MealSelection.where(production_day:[production_day_1,production_day_2]).select do |ms|
            (ms.pork.to_i + ms.beef.to_i + ms.poultry.to_i != (ms.production_day.wday == 0 ? ms.customer.regular_meals_on_monday.to_i : ms.customer.regular_meals_on_thursday.to_i)) || (ms.green_1.to_i + ms.green_2.to_i != (ms.production_day.wday == 0 ? ms.customer.green_meals_on_monday.to_i : ms.customer.green_meals_on_thursday.to_i))
        end

        mismatched_rows.each do |mmr|
            mmr_reg = mmr.pork.to_i + mmr.beef.to_i + mmr.poultry.to_i
            mmr_grn = mmr.green_1.to_i + mmr.green_2.to_i
            cust_reg = mmr.production_day.wday == 0 ? mmr.customer.regular_meals_on_monday.to_i : mmr.customer.regular_meals_on_thursday.to_i
            cust_grn = mmr.production_day.wday == 0 ? mmr.customer.green_meals_on_monday.to_i : mmr.customer.green_meals_on_thursday.to_i
            
            change_reg = cust_reg.to_i - mmr_reg.to_i
            change_grn = cust_grn.to_i - mmr_grn.to_i

            if change_reg > 0
                array_of_eligible_meals = []
                array_of_eligible_meals.push("pork") unless mmr.customer.no_pork?
                array_of_eligible_meals.push("beef") unless mmr.customer.no_beef?
                array_of_eligible_meals.push("poultry") unless mmr.customer.no_poultry?
                array_of_eligible_meals.shuffle!

                unless array_of_eligible_meals.blank?
                    while change_reg > 0 do
                        el = array_of_eligible_meals.slice!(0)
                        if el == "pork"
                            mmr.update_attributes(pork:mmr.pork.to_i+1)
                        elsif el == "beef"
                            mmr.update_attributes(beef:mmr.beef.to_i+1)
                        elsif el == "poultry"
                            mmr.update_attributes(poultry:mmr.poultry.to_i+1)
                        end
                        array_of_eligible_meals.push(el)
                        change_reg -= 1
                    end
                end
            elsif change_reg < 0
                array_of_non_eligible_meals = []
                array_of_non_eligible_meals.push("pork") if mmr.customer.no_pork?
                array_of_non_eligible_meals.push("beef") if mmr.customer.no_beef?
                array_of_non_eligible_meals.push("poultry") if mmr.customer.no_poultry?
                array_of_non_eligible_meals.shuffle!

                unless array_of_non_eligible_meals.blank?
                    total_non_eligible_meals = array_of_non_eligible_meals.inject {|sum,anem| 
                        if anem == "pork"
                            sum + mmr.pork.to_i
                        elsif anem == "beef"
                            sum + mmr.beef.to_i
                        elsif anem == "poultry"
                            sum + mmr.poultry.to_i
                        end
                    }.to_i
                
                    if change_reg.abs >= total_non_eligible_meals
                        array_of_non_eligible_meals.each { |anem|
                            if anem == "pork"
                                mmr.update_attributes(pork:0)
                            elsif anem == "beef"
                                mmr.update_attributes(beef:0)
                            elsif anem == "poultry"
                                mmr.update_attributes(poultry:0)
                            end                            
                        }
                        change_reg += total_non_eligible_meals
                    else
                        while change_reg < 0 do
                            el = array_of_non_eligible_meals.slice!(0)
                            do_not_increment = false
                            if el == "pork"
                                if mmr.pork.to_i > 0
                                    mmr.update_attributes(pork:mmr.pork.to_i-1)
                                else
                                    do_not_increment = true
                                end
                            elsif el == "beef"
                                if mmr.beef.to_i > 0
                                    mmr.update_attributes(beef:mmr.beef.to_i-1) 
                                else
                                    do_not_increment = true 
                                end
                            elsif el == "poultry"
                                if mmr.poultry.to_i > 0
                                    mmr.update_attributes(poultry:mmr.poultry.to_i-1)
                                else 
                                    do_not_increment = true
                                end
                            end
                            array_of_non_eligible_meals.push(el)
                            change_reg += 1 unless do_not_increment
                        end                        
                    end
                end

                array_of_eligible_meals = []
                array_of_eligible_meals.push("pork") unless mmr.customer.no_pork?
                array_of_eligible_meals.push("beef") unless mmr.customer.no_beef?
                array_of_eligible_meals.push("poultry") unless mmr.customer.no_poultry?
                array_of_eligible_meals.shuffle!

                unless array_of_eligible_meals.blank?
                    while change_reg < 0 do
                        el = array_of_eligible_meals.slice!(0)
                        do_not_increment = false
                        if el == "pork"
                            if mmr.pork.to_i > 0
                                mmr.update_attributes(pork:mmr.pork.to_i-1)
                            else
                                do_not_increment = true
                            end
                        elsif el == "beef"
                            if mmr.beef.to_i > 0
                                mmr.update_attributes(beef:mmr.beef.to_i-1)
                            else
                                do_not_increment = true
                            end
                        elsif el == "poultry"
                            if mmr.poultry.to_i > 0
                                mmr.update_attributes(poultry:mmr.poultry.to_i-1)
                            else
                                do_not_increment = true
                            end
                        end
                        array_of_eligible_meals.push(el)
                        change_reg += 1 unless do_not_increment
                    end
                end
            end

            if change_grn != 0
                array_of_eligible_meals = ["green_1","green_2"].shuffle!
                increment = (change_grn/(change_grn.abs)).to_i
                while change_grn != 0 do
                    difference = 0
                    el = array_of_eligible_meals.slice!(0)
                    if el == "green_1"
                        mmr.update_attributes(green_1:mmr.green_1.to_i+increment)
                        if mmr.green_1.to_i < 0
                            difference = 0 - mmr.green_1.to_i
                            mmr.update_attributes(green_1:0)
                        end
                    elsif el == "green_2"
                        mmr.update_attributes(green_2:mmr.green_2.to_i+increment)
                        if mmr.green_2.to_i < 0
                            difference = 0 - mmr.green_2.to_i
                            mmr.update_attributes(green_2:0)
                        end
                    end
                    array_of_eligible_meals.push(el)
                    change_grn -= increment
                    change_grn -= difference
                    difference = 0
                end
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
                        queue_item.add_to_record
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
                    queue_item.add_to_record
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
                        queue_item.add_to_record
                        queue_item.destroy
                    else
                        stripe_trial_end_date = Date.today < current_customer.first_pick_up_date ? queue_item.end_date + 7.days + 23.9.hours : queue_item.end_date + 23.9.hours
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        stripe_subscription.trial_end = (stripe_trial_end_date).to_time.to_i
                        stripe_subscription.prorate = false
                        if stripe_subscription.save
                            current_customer.update(paused?:"yes", pause_end_date:queue_item.end_date-1, next_pick_up_date:queue_item.end_date)
                            current_customer.stop_requests.create(request_type:'pause',start_date:queue_item.start_date, end_date:queue_item.end_date-1, requested_date: queue_item.created_at)
                            queue_item.add_to_record
                            queue_item.destroy
                        end
                    end

                elsif queue_item.stop_type == 'cancel'
                    if current_customer.stripe_subscription_id.blank?
                        current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                        current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date,cancel_reason:queue_item.cancel_reason, requested_date: queue_item.created_at)
                        queue_item.add_to_record
                        queue_item.destroy                        
                    else
                        if Date.today < current_customer.first_pick_up_date
                            charge_id = Stripe::Charge.all(customer:current_customer.stripe_customer_id,limit:1).data[0].id
                            charge = Stripe::Charge.retrieve(charge_id)
                            internal_refund_id = nil
                            if stripe_refund_response = charge.refunds.create
                                newly_created_refund = Refund.create(
                                        stripe_customer_id: current_customer.stripe_customer_id, 
                                        refund_week:StartDate.first.start_date, 
                                        charge_week:Date.today,
                                        charge_id:charge_id, 
                                        meals_refunded: current_customer.total_meals_per_week, 
                                        amount_refunded: (current_customer.total_meals_per_week * 6.99 * 1.13 * 100).round, 
                                        refund_reason: "Customer cancelled before starting", 
                                        stripe_refund_id: stripe_refund_response.id
                                )
                                newly_created_refund.internal_refund_id = internal_refund_id.nil? ? newly_created_refund.id : internal_refund_id
                                if newly_created_refund.save
                                    internal_refund_id ||= newly_created_refund.id
                                end
                            end
                        end
                        stripe_subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                        if stripe_subscription.delete
                            current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                            current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date,cancel_reason:queue_item.cancel_reason, requested_date: queue_item.created_at)
                            queue_item.add_to_record
                            queue_item.destroy
                        end
                    end
                elsif queue_item.stop_type == 'restart'
                    if current_customer.stripe_subscription_id.blank?
                        start_date_update = queue_item.start_date
                        if current_customer.sponsored?
                            current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil,pause_cancel_request:nil) 
                            current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                            queue_item.add_to_record
                            queue_item.destroy                            
                        else
                            current_customer_interval = current_customer.interval.blank? ? "week" : current_customer.interval
                            current_customer_interval_count = current_customer.interval_count.blank? ? 1 : current_customer.interval_count
                            meals_per_week = Subscription.where(weekly_meals:current_customer.total_meals_per_week, interval: current_customer_interval, interval_count:current_customer_interval_count).take.stripe_plan_id
                            
                            if Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:(start_date_update + 23.9.hours).to_time.to_i)
                                new_subscription_id = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.all.data[0].id
                                current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil, stripe_subscription_id: new_subscription_id,pause_cancel_request:nil) 
                                current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                                queue_item.add_to_record
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
                            queue_item.add_to_record
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
                queue_item.add_to_record
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
