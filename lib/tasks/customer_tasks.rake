
namespace :customers do
    desc 'push system start date to the next Monday'
    task :push_start_date, [:number_of_weeks] => [:environment] do |t, args|        
        new_start_date = Chowdy::Application.closest_date(args[:number_of_weeks],1)
        new_start_date = new_start_date == "2015-12-28".to_date ? Chowdy::Application.closest_date(1,1,new_start_date) : new_start_date #Christmas break for 2015
        if StartDate.first.update(start_date: new_start_date)        
            puts "Start date pushed to #{Chowdy::Application.closest_date(args[:number_of_weeks],1)}" 
            
        end
    end

    desc 'Change all Wandas customers to Red Bench'
    task :wandas_to_red_bench => [:environment] do 
        Customer.where("monday_pickup_hub ilike ?", "%wanda%").each do |c|
            c.update_attributes(monday_pickup_hub:"611 Yonge St. (The Red Bench)")
        end
        Customer.where("thursday_pickup_hub ilike ?", "%wanda%").each do |c|
            c.update_attributes(thursday_pickup_hub:"611 Yonge St. (The Red Bench)")
        end
        Customer.where("monday_delivery_hub ilike ?", "%wanda%").each do |c|
            c.update_attributes(monday_delivery_hub:"611 Yonge St. (The Red Bench)")
        end
        Customer.where("monday_delivery_hub ilike ?", "%wanda%").each do |c|
            c.update_attributes(monday_delivery_hub:"611 Yonge St. (The Red Bench)")
        end
    end


    desc 'push Marketplace delivery date to the next  Monday'
    task :push_marketplace_delivery_date, [:number_of_weeks] => [:environment] do |t, args|        
        new_start_date = Chowdy::Application.closest_date(args[:number_of_weeks],1)
        if PartnerProductDeliveryDate.first.update(delivery_date: new_start_date)        
            puts "Delivery date pushed to #{Chowdy::Application.closest_date(args[:number_of_weeks],1)}" 
        end
    end

    desc 'update status information for customers restarting after pause'
    task :restart_status => [:environment] do
        Customer.where(paused?: ["yes","Yes"], pause_end_date: [Chowdy::Application.closest_date(1,7), Chowdy::Application.closest_date(1,1)]).each do |customer|
            customer.update(paused?:nil, pause_end_date:nil,pause_cancel_request:nil,next_pick_up_date:Chowdy::Application.closest_date(1,1))
        end
    end

    desc 'look for unexecuted requests'
    task :find_unexecuted_requests => [:environment] do
        anomaly_array = []
        if StopQueue.where("created_at < ?",Chowdy::Application.closest_date(-1,5)).length > 0
            StopQueue.where("created_at < ?",Chowdy::Application.closest_date(-1,5)).each do |sq|
                anomaly_array.push([sq.customer,"unprocessed stop request with associated cut off of #{sq.associated_cutoff.strftime("%Y-%m-%d")}"])
            end
        end

        if anomaly_array.length > 0 
            CustomerMailer.delay.anomaly_report(anomaly_array)
        end
    end

    desc 'look for anomalies in the customer data'
    task :scan_customer_data_anomalies => [:environment] do
        anomaly_array = []
        active_customers = Customer.where(active?: ["yes","Yes"])

        #negative meal counts
        negative_meal_count_customers = Customer.where{(active? >> ["yes","Yes"]) & ((regular_meals_on_monday < 0) | (green_meals_on_monday < 0 )| (regular_meals_on_thursday < 0) | (green_meals_on_thursday < 0))}
        negative_meal_count_customers.each {|c| anomaly_array.push([c,"negative meal count"]) }

        #pick up date not on a monday
        wrong_pick_up_date_customers = Customer.where("extract(DOW from next_pick_up_date) != 1")
        wrong_pick_up_date_customers.each {|c| anomaly_array.push([c,"next pick up not on Monday"])}

        #pick up date not updated properly
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        out_of_date_pick_up_date_customers = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date < current_pick_up_date)}
        out_of_date_pick_up_date_customers.each {|c| anomaly_array.push([c,"Next pick up date before the current system pick up date"])}

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

    desc 'pause all currently active customers for one week 2015'
    task :pause_all_active_one_week => [:environment] do
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        active_nonpaused_customers = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:current_pick_up_date)
        active_nonpaused_customers.each do |c|
            if c.stop_queues.where("stop_type ilike ? or stop_type ilike ?", "pause", "cancel").length == 0
                c.stop_queues.create(stop_type:'pause',associated_cutoff:Chowdy::Application.closest_date(1,4), end_date:"2016-01-04".to_date, start_date:"2015-12-28".to_date)
            end
        end
    end


    desc 'Send emails to customers to remind them to restart their subscription'
    task :restart_reminder_emails, [:number_of_days,:duration_before_for_pause,:duration_after_for_pause] => [:environment] do |t, args|        
        cancelled_customers = ReminderEmailLog.generate_customer_list(args[:number_of_days])
        paused_customers = ReminderEmailLog.paused_customer_list(args[:duration_before_for_pause],args[:duration_after_for_pause])
        ReminderEmailLog.generate_restart_email(cancelled_customers,500)
        ReminderEmailLog.generate_restart_email(paused_customers,500)
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
            mmr_total = mmr_reg + mmr_grn
            cust_reg = mmr.production_day.wday == 0 ? mmr.customer.regular_meals_on_monday.to_i : mmr.customer.regular_meals_on_thursday.to_i
            cust_grn = mmr.production_day.wday == 0 ? mmr.customer.green_meals_on_monday.to_i : mmr.customer.green_meals_on_thursday.to_i
            cust_total = cust_reg + cust_grn

            # change_reg = cust_reg.to_i - mmr_reg.to_i
            change_grn = cust_grn.to_i - mmr_grn.to_i
            change_total = cust_total.to_i - mmr_total.to_i



            if change_total > 0
                array_of_eligible_meals = []
                array_of_eligible_meals.push("pork") unless mmr.customer.no_pork?
                array_of_eligible_meals.push("beef") unless mmr.customer.no_beef?
                array_of_eligible_meals.push("poultry") unless mmr.customer.no_poultry?

                array_of_eligible_green = []
                array_of_eligible_green.push("green_1")
                array_of_eligible_green.push("green_2")

                while change_grn > 0
                    array_of_eligible_green.sort_by! {|type| mmr.send(type.to_sym).to_i}
                    do_not_increment = false
                    el = array_of_eligible_green.slice!(0)
                    if el == "green_1"
                        if change_grn > 0
                            mmr.update_attributes(green_1:mmr.green_1.to_i+1)
                            change_grn -= 1
                        else 
                            do_not_increment = true
                        end
                    elsif el == "green_2"
                        if change_grn > 0
                            mmr.update_attributes(green_2:mmr.green_2.to_i+1)
                            change_grn -= 1
                        else
                            do_not_increment = true
                        end
                    end
                    array_of_eligible_green.push(el)
                    unless do_not_increment
                        change_total -= 1
                    end
                    do_not_increment = false
                end

                while change_total > 0 do
                    array_of_eligible_meals.sort_by! {|type| mmr.send(type.to_sym).to_i}
                    do_not_increment = false
                    el = array_of_eligible_meals.slice!(0)
                    if el == "pork"
                        mmr.update_attributes(pork:mmr.pork.to_i+1)
                    elsif el == "beef"
                        mmr.update_attributes(beef:mmr.beef.to_i+1)
                    elsif el == "poultry"
                        mmr.update_attributes(poultry:mmr.poultry.to_i+1)
                    end
                    array_of_eligible_meals.push(el)
                    unless do_not_increment
                        change_total -= 1
                    end
                    do_not_increment = false
                end
            elsif change_total < 0

                array_of_eligible_green = []
                array_of_eligible_green.push("green_1")
                array_of_eligible_green.push("green_2")

                while change_grn < 0
                    array_of_eligible_green.sort_by! {|type| mmr.send(type.to_sym).to_i}.reverse!
                    do_not_increment = false
                    el = array_of_eligible_green.slice!(0)
                    if el == "green_1"
                        if mmr.green_1.to_i > 0
                            mmr.update_attributes(green_1:mmr.green_1.to_i-1)
                            change_grn += 1
                        else 
                            do_not_increment = true
                        end
                    elsif el == "green_2"
                        if mmr.green_2.to_i > 0
                            mmr.update_attributes(green_2:mmr.green_2.to_i-1)
                            change_grn += 1
                        else
                            do_not_increment = true
                        end
                    end
                    array_of_eligible_green.push(el)
                    unless do_not_increment
                        change_total += 1
                    end
                    do_not_increment = false
                end


                if change_total < 0

                    array_of_non_eligible_meals = []
                    array_of_non_eligible_meals.push("pork") if mmr.customer.no_pork?
                    array_of_non_eligible_meals.push("beef") if mmr.customer.no_beef?
                    array_of_non_eligible_meals.push("poultry") if mmr.customer.no_poultry?

                    unless array_of_non_eligible_meals.blank?
                        total_non_eligible_meals = array_of_non_eligible_meals.inject(0) {|sum,anem| 
                            if anem == "pork"
                                sum + mmr.pork.to_i
                            elsif anem == "beef"
                                sum + mmr.beef.to_i
                            elsif anem == "poultry"
                                sum + mmr.poultry.to_i
                            end
                        }.to_i


                        if change_total.abs >= total_non_eligible_meals
                            array_of_non_eligible_meals.each { |anem|
                                if anem == "pork"
                                    mmr.update_attributes(pork:0)
                                elsif anem == "beef"
                                    mmr.update_attributes(beef:0)
                                elsif anem == "poultry"
                                    mmr.update_attributes(poultry:0)
                                end                            
                            }
                            change_total += total_non_eligible_meals
                        else
                            while change_total < 0 do
                                array_of_non_eligible_meals.sort_by! {|type| mmr.send(type.to_sym).to_i}.reverse!
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
                    array_of_eligible_meals.push("pork") 
                    array_of_eligible_meals.push("beef") 
                    array_of_eligible_meals.push("poultry")

                    unless array_of_eligible_meals.blank?
                        while change_total < 0 do
                            array_of_eligible_meals.sort_by! {|type| mmr.send(type.to_sym).to_i}.reverse!
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
                            unless do_not_increment
                                change_total += 1 
                            end
                            do_not_increment = false
                        end
                    end
                end
            end

            # if change_reg > 0
            #     array_of_eligible_meals = []
            #     array_of_eligible_meals.push("pork") unless mmr.customer.no_pork?
            #     array_of_eligible_meals.push("beef") unless mmr.customer.no_beef?
            #     array_of_eligible_meals.push("poultry") unless mmr.customer.no_poultry?
            #     array_of_eligible_meals.shuffle!

            #     unless array_of_eligible_meals.blank?
            #         while change_reg > 0 do
            #             el = array_of_eligible_meals.slice!(0)
            #             if el == "pork"
            #                 mmr.update_attributes(pork:mmr.pork.to_i+1)
            #             elsif el == "beef"
            #                 mmr.update_attributes(beef:mmr.beef.to_i+1)
            #             elsif el == "poultry"
            #                 mmr.update_attributes(poultry:mmr.poultry.to_i+1)
            #             end
            #             array_of_eligible_meals.push(el)
            #             change_reg -= 1
            #         end
            #     end
            # elsif change_reg < 0
            #     array_of_non_eligible_meals = []
            #     array_of_non_eligible_meals.push("pork") if mmr.customer.no_pork?
            #     array_of_non_eligible_meals.push("beef") if mmr.customer.no_beef?
            #     array_of_non_eligible_meals.push("poultry") if mmr.customer.no_poultry?
            #     array_of_non_eligible_meals.shuffle!

            #     unless array_of_non_eligible_meals.blank?
            #         total_non_eligible_meals = array_of_non_eligible_meals.inject {|sum,anem| 
            #             if anem == "pork"
            #                 sum + mmr.pork.to_i
            #             elsif anem == "beef"
            #                 sum + mmr.beef.to_i
            #             elsif anem == "poultry"
            #                 sum + mmr.poultry.to_i
            #             end
            #         }.to_i
                
            #         if change_reg.abs >= total_non_eligible_meals
            #             array_of_non_eligible_meals.each { |anem|
            #                 if anem == "pork"
            #                     mmr.update_attributes(pork:0)
            #                 elsif anem == "beef"
            #                     mmr.update_attributes(beef:0)
            #                 elsif anem == "poultry"
            #                     mmr.update_attributes(poultry:0)
            #                 end                            
            #             }
            #             change_reg += total_non_eligible_meals
            #         else
            #             while change_reg < 0 do
            #                 el = array_of_non_eligible_meals.slice!(0)
            #                 do_not_increment = false
            #                 if el == "pork"
            #                     if mmr.pork.to_i > 0
            #                         mmr.update_attributes(pork:mmr.pork.to_i-1)
            #                     else
            #                         do_not_increment = true
            #                     end
            #                 elsif el == "beef"
            #                     if mmr.beef.to_i > 0
            #                         mmr.update_attributes(beef:mmr.beef.to_i-1) 
            #                     else
            #                         do_not_increment = true 
            #                     end
            #                 elsif el == "poultry"
            #                     if mmr.poultry.to_i > 0
            #                         mmr.update_attributes(poultry:mmr.poultry.to_i-1)
            #                     else 
            #                         do_not_increment = true
            #                     end
            #                 end
            #                 array_of_non_eligible_meals.push(el)
            #                 change_reg += 1 unless do_not_increment
            #             end                        
            #         end
            #     end

            #     array_of_eligible_meals = []
            #     array_of_eligible_meals.push("pork") unless mmr.customer.no_pork?
            #     array_of_eligible_meals.push("beef") unless mmr.customer.no_beef?
            #     array_of_eligible_meals.push("poultry") unless mmr.customer.no_poultry?
            #     array_of_eligible_meals.shuffle!

            #     unless array_of_eligible_meals.blank?
            #         while change_reg < 0 do
            #             el = array_of_eligible_meals.slice!(0)
            #             do_not_increment = false
            #             if el == "pork"
            #                 if mmr.pork.to_i > 0
            #                     mmr.update_attributes(pork:mmr.pork.to_i-1)
            #                 else
            #                     do_not_increment = true
            #                 end
            #             elsif el == "beef"
            #                 if mmr.beef.to_i > 0
            #                     mmr.update_attributes(beef:mmr.beef.to_i-1)
            #                 else
            #                     do_not_increment = true
            #                 end
            #             elsif el == "poultry"
            #                 if mmr.poultry.to_i > 0
            #                     mmr.update_attributes(poultry:mmr.poultry.to_i-1)
            #                 else
            #                     do_not_increment = true
            #                 end
            #             end
            #             array_of_eligible_meals.push(el)
            #             change_reg += 1 unless do_not_increment
            #         end
            #     end
            # end

            # if change_grn != 0
            #     array_of_eligible_meals = ["green_1","green_2"].shuffle!
            #     increment = (change_grn/(change_grn.abs)).to_i
            #     while change_grn != 0 do
            #         difference = 0
            #         el = array_of_eligible_meals.slice!(0)
            #         if el == "green_1"
            #             mmr.update_attributes(green_1:mmr.green_1.to_i+increment)
            #             if mmr.green_1.to_i < 0
            #                 difference = 0 - mmr.green_1.to_i
            #                 mmr.update_attributes(green_1:0)
            #             end
            #         elsif el == "green_2"
            #             mmr.update_attributes(green_2:mmr.green_2.to_i+increment)
            #             if mmr.green_2.to_i < 0
            #                 difference = 0 - mmr.green_2.to_i
            #                 mmr.update_attributes(green_2:0)
            #             end
            #         end
            #         array_of_eligible_meals.push(el)
            #         change_grn -= increment
            #         change_grn -= difference
            #         difference = 0
            #     end
            # end

        end
    end




    desc 'pause/cancel/restart customers'
    task :execute_pause_cancel_restart_queue, [:distance] => [:environment] do |t, args|
        if StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer

                begin

                    if Date.today < current_customer.first_pick_up_date
                        raw_difference = queue_item.updated_meals - current_customer.total_meals_per_week
                        applicable_gift = current_customer.gifts.take
                        if applicable_gift.blank?
                            if raw_difference > 0
                                difference = raw_difference
                                price = current_customer.price_increase_2015? ? 799 : 699

                                Stripe::InvoiceItem.create(
                                    customer: current_customer.stripe_customer_id,
                                    amount: (difference * price * 1.13).round,
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
                                price = current_customer.price_increase_2015? ? 799 : 699 
                                stripe_refund_response = charge.refunds.create(amount: (difference * price * 1.13).round)

                                newly_created_refund = Refund.create(
                                        stripe_customer_id: current_customer.stripe_customer_id, 
                                        refund_week:StartDate.first.start_date, 
                                        charge_week:Date.today,
                                        charge_id:charge_id, 
                                        meals_refunded: difference, 
                                        amount_refunded: (difference * price * 1.13).round, 
                                        refund_reason: "Subscription adjustment before first week", 
                                        stripe_refund_id: stripe_refund_response.id
                                )
                                newly_created_refund.internal_refund_id = newly_created_refund.id
                                newly_created_refund.save
                                # take this bit out after testing
                                CustomerMailer.delay.rescued_error(current_customer,'No error. Just an automatic refund was created for this customer so look into it')
                            end
                        else
                            if raw_difference > 0
                                price = current_customer.price_increase_2015? ? 799 : 699 
                                difference = raw_difference 
                                remain_0 = current_customer.gifts.take.remaining_gift_amount
                                    ii = Stripe::InvoiceItem.all(customer:current_customer.stripe_customer_id,limit:1).data.select {|ii| ii.amount < 0 && ii.description.match('gift') }
                                ii_amount =  ii.blank? ? 0 : ii[0].amount.abs

                                chargeable_difference = [(difference * price * 1.13).round - remain_0 - ii_amount, 0].max

                                if chargeable_difference > 0
                                    Stripe::InvoiceItem.create(
                                        customer: current_customer.stripe_customer_id,
                                        amount: chargeable_difference,
                                        currency: 'CAD',
                                        description: "First-week adjustment for #{difference} extra meals requested after sign up above gift card amount"
                                    )
                                    Stripe::Invoice.create(
                                        customer: current_customer.stripe_customer_id
                                    )
                                end

                                remain_1 = [remain_0 + ii_amount - (difference * price * 1.13).round,0].max
                                applicable_gift.update_attributes(remaining_gift_amount:remain_1)
                                applicable_gift.gift_remains.destroy_all
                                applicable_gift.gift_redemptions.destroy_all

                                applicable_gift.gift_redemptions.create(
                                    stripe_customer_id:current_customer.stripe_customer_id,
                                    amount_redeemed:[(queue_item.updated_meals.to_i * price * 1.13).round,applicable_gift.original_gift_amount].min,
                                    amount_remaining:remain_1
                                )

                                ii[0].delete unless ii.blank?

                                if remain_1 == 0 && remain_0 != 0
                                    associated_cutoff = Chowdy::Application.closest_date(1,4,StartDate.first.start_date) #Thursday after customer starts
                                    adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1,associated_cutoff)
                                    current_customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:"Gift card #{applicable_gift.gift_code} ran out")
                                end
                                
                            elsif raw_difference < 0
                                difference = -raw_difference
                                price = current_customer.price_increase_2015? ? 799 : 699 
                                ii = Stripe::InvoiceItem.all(customer:current_customer.stripe_customer_id,limit:1).data.select {|ii| ii.amount < 0 && ii.description.match('gift') }
                                charge = Stripe::Charge.all(customer:current_customer.stripe_customer_id,limit:1).data[0]
                                unrefunded_charge_amount = charge.amount.to_i - charge.amount_refunded.to_i
                                refundable_difference = [(difference * price * 1.13).round,unrefunded_charge_amount].min

                                if refundable_difference > 0
                                    stripe_refund_response = charge.refunds.create(amount: refundable_difference)

                                    newly_created_refund = Refund.create(
                                            stripe_customer_id: current_customer.stripe_customer_id, 
                                            refund_week:StartDate.first.start_date, 
                                            charge_week:Date.today,
                                            charge_id:charge.id, 
                                            meals_refunded: (refundable_difference.to_f/price.to_f/1.13).round.to_i, 
                                            amount_refunded: refundable_difference, 
                                            refund_reason: "Subscription adjustment before first week", 
                                            stripe_refund_id: stripe_refund_response.id
                                    )
                                    newly_created_refund.internal_refund_id = newly_created_refund.id
                                    newly_created_refund.save                                    
                                end

                                remain_1 = [applicable_gift.original_gift_amount - (queue_item.updated_meals.to_i * price * 1.13).round,0].max
                                applicable_gift.update_attributes(remaining_gift_amount:remain_1)
                                applicable_gift.gift_remains.destroy_all
                                applicable_gift.gift_redemptions.destroy_all
                                applicable_gift.gift_redemptions.create(
                                    stripe_customer_id:current_customer.stripe_customer_id,
                                    amount_redeemed:[(queue_item.updated_meals.to_i * price * 1.13).round,applicable_gift.original_gift_amount].min,
                                    amount_remaining:remain_1
                                )
                                current_customer.stop_queues.where("stop_type ilike ? and cancel_reason ilike ?", "cancel","%gift%").destroy_all if remain_1 > 0
                                ii[0].delete unless ii.blank?
                            end

                        end
                    end

                    applicable_price = current_customer.price_increase_2015? ? 799 : 699
                    plan_match = Subscription.where(weekly_meals:queue_item.updated_meals, interval: "week",interval_count:1, price:applicable_price)

                    if plan_match.blank?
                        id = current_customer.price_increase_2015? ? queue_item.updated_meals.to_s+"mealswk_pi" : queue_item.updated_meals.to_s+"mealswk"
                        amount = ((queue_item.updated_meals)*applicable_price*1.13).round
                        statement_descriptor = "WK PLN " + queue_item.updated_meals.to_s
                        if Stripe::Plan.create(id:id, amount:amount,currency:"CAD",interval:"week",interval_count:1, name:id, statement_descriptor: statement_descriptor)
                            plan_match = Subscription.create(weekly_meals:queue_item.updated_meals,stripe_plan_id:id,interval:"week",interval_count:1, price:applicable_price)

                            if (queue_item.updated_meals == current_customer.total_meals_per_week) && ((current_customer.interval.blank? ? "week" : current_customer.interval) == "week") && ((current_customer.interval_count.blank? ? 1 : current_customer.interval) == 1)
                                current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu)
                            else
                                if current_customer.stripe_subscription_id.blank?
                                    current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                    update_interval = nil
                                    update_interval_count = nil
                                    current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                                else
                                    subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                                    _current_period_end = subscription.current_period_end
                                    subscription.plan = plan_match.stripe_plan_id
                                    subscription.trial_end = _current_period_end
                                    subscription.prorate = false  
                                    if subscription.save                      
                                        current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                        update_interval = nil
                                        update_interval_count = nil
                                        current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                         
                                    end
                                end
                            end
                        end
                    else
                        if (queue_item.updated_meals == current_customer.total_meals_per_week) && ((current_customer.interval.blank? ? "week" : current_customer.interval) == "week") && ((current_customer.interval_count.blank? ? 1 : current_customer.interval) == 1)
                            current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                            update_interval = nil
                            update_interval_count = nil
                            current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                 
                        else
                            if current_customer.stripe_subscription_id.blank?
                                current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                            else
                                subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                                _current_period_end = subscription.current_period_end
                                subscription.plan = plan_match.take.stripe_plan_id
                                subscription.trial_end = _current_period_end
                                subscription.prorate = false  
                                if subscription.save                      
                                    current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                    update_interval = nil
                                    update_interval_count = nil
                                    current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                                end
                            end
                        end
                    end

                    if Date.today < current_customer.first_pick_up_date
                        Gift.redeem_gift_code(applicable_gift.gift_code,nil,current_customer,false) unless applicable_gift.blank? #attach a negative invoice item  
                    end

                    # if there's currently negative invoices associated with gift, we need to adjust the negative invoice amount to reflect the updated. This block doesn't need to be run twice 
                    gift_remain = current_customer.gift_remains
                    
                    unless gift_remain.blank? || Date.today < current_customer.first_pick_up_date
                        gift_remain.each do |gr|
                            begin
                                ii = Stripe::InvoiceItem.all(customer:current_customer.stripe_customer_id,limit:1).data.select {|ii| ii.amount < 0  && ii.description.match('gift') }[0]
                                ii_amount = ii.amount.abs
                                ii.delete
                                gr.gift.update_attributes(remaining_gift_amount:gr.gift.remaining_gift_amount+ii_amount)
                            rescue => error
                                puts '---------------------------------------------------'
                                puts "something went wrong trying to delete Invoice Item before attaching another one during change_sub operation"
                                puts error.message
                                puts '---------------------------------------------------' 
                                CustomerMailer.rescued_error(current_customer,"something went wrong trying to delete Invoice Item before attaching another one during change_sub operation: "+error.message.inspect).deliver                    
                            else
                                gr.gift.gift_redemptions.order(id: :desc).limit(1).take.destroy
                                Gift.redeem_gift_code(gr.gift.gift_code,nil,current_customer,false)
                                gr.destroy
                            end
                        end
                    end

                rescue => error
                    puts '---------------------------------------------------'
                    puts "something went wrong trying to change subscription during weekly task"
                    puts error.message
                    puts '---------------------------------------------------' 
                    CustomerMailer.rescued_error(current_customer,error.message).deliver
                else
                    unless current_customer.stripe_subscription_id.blank? #if there is no subscription we need to run this whole block again (because there's a chance that the customer is resuming from cancel and if so there will be subscription ID once the resume block code below is run)
                        if current_customer.user
                            current_customer.user.log_activity("System: subscription meal count updated to #{queue_item.updated_meals} meals per week")
                        end
                        queue_item.add_to_record
                        queue_item.destroy
                    end
                end

            end
        end

        if StopQueue.where(stop_type: ["change_hub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_hub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                if queue_item.customer.update_attributes(hub:queue_item.cancel_reason,monday_pickup_hub:queue_item.cancel_reason,thursday_pickup_hub:queue_item.cancel_reason,recurring_delivery:nil)
                    if queue_item.customer.user
                        queue_item.customer.user.log_activity("System: hub changed")
                    end
                    queue_item.add_to_record
                    queue_item.destroy
                end
            end
        end

        if StopQueue.where(stop_type: ["cancel","pause","restart"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["cancel","pause","restart"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|                
                current_customer = queue_item.customer
                
                begin

                    if queue_item.stop_type == 'pause'

                        if current_customer.stripe_subscription_id.blank?
                            current_customer.update(paused?:"yes", pause_end_date:queue_item.end_date-1, next_pick_up_date:queue_item.end_date)
                            current_customer.stop_requests.create(request_type:'pause',start_date:queue_item.start_date, end_date:queue_item.end_date-1, requested_date: queue_item.created_at)
                            if current_customer.user
                                current_customer.user.log_activity("System: subscription paused until #{queue_item.end_date-1}")
                            end
                            CustomerMailer.delay.pause_confirmation(current_customer,queue_item.start_date,queue_item.end_date)
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
                                if current_customer.user
                                    current_customer.user.log_activity("System: subscription paused until #{queue_item.end_date-1}")
                                end
                                CustomerMailer.delay.pause_confirmation(current_customer,queue_item.start_date,queue_item.end_date)
                                queue_item.add_to_record
                                queue_item.destroy
                            end
                        end



                    elsif queue_item.stop_type == 'cancel'
                        if current_customer.stripe_subscription_id.blank?
                            current_customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                            current_customer.stop_requests.create(request_type:'cancel',start_date:queue_item.start_date,cancel_reason:queue_item.cancel_reason, requested_date: queue_item.created_at)
                            if current_customer.user
                                current_customer.user.log_activity("System: subscription cancelled")
                            end
                            queue_item.add_to_record
                            queue_item.destroy                        
                        else
                            if Date.today < current_customer.first_pick_up_date
                                price = current_customer.price_increase_2015? ? 799 : 699
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
                                            amount_refunded: (current_customer.total_meals_per_week * price * 1.13).round, 
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
                                if current_customer.user
                                    current_customer.user.log_activity("System: subscription cancelled")
                                end
                                current_customer.stop_queues.where("stop_type ilike ?","%pause%").destroy_all
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
                                if current_customer.user
                                    current_customer.user.log_activity("System: subscription restarted")
                                end
                                queue_item.add_to_record
                                queue_item.destroy                            
                            else
                                current_customer_interval = current_customer.interval.blank? ? "week" : current_customer.interval
                                current_customer_interval_count = current_customer.interval_count.blank? ? 1 : current_customer.interval_count
                                applicable_price = current_customer.price_increase_2015? ? 799 : 699
                                meals_per_week = Subscription.where(weekly_meals:current_customer.total_meals_per_week, interval: current_customer_interval, interval_count:current_customer_interval_count,price: applicable_price).take.stripe_plan_id
                                
                                if Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:(start_date_update + 23.9.hours).to_time.to_i)
                                    new_subscription_id = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.all.data[0].id
                                    current_customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil, stripe_subscription_id: new_subscription_id,pause_cancel_request:nil) 
                                    current_customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1) unless current_customer.stop_requests.order(created_at: :desc).limit(1).take.blank?
                                    if current_customer.user
                                        current_customer.user.log_activity("System: subscription restarted")
                                    end
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
                                if current_customer.user
                                    current_customer.user.log_activity("System: subscription restarted")
                                end
                                queue_item.add_to_record
                                queue_item.destroy
                            end
                        end
                    end

                rescue => error
                    puts '---------------------------------------------------'
                    puts "something went wrong trying to change subscription during weekly task"
                    puts error.message
                    puts current_customer.email
                    puts '---------------------------------------------------' 
                    CustomerMailer.rescued_error(current_customer,error.message).deliver
                else

                end
            end
        end
        #run the change subscription code the second time
        if StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).length > 0
            StopQueue.where(stop_type: ["change_sub"], associated_cutoff: Chowdy::Application.closest_date(args[:distance],4)).each do |queue_item|
                current_customer = queue_item.customer


                begin
                    applicable_price = current_customer.price_increase_2015? ? 799 : 699
                    plan_match = Subscription.where(weekly_meals:queue_item.updated_meals, interval: "week",interval_count:1)

                    if plan_match.blank?
                        id = current_customer.price_increase_2015? ? queue_item.updated_meals.to_s+"mealswk_pi" : queue_item.updated_meals.to_s+"mealswk"
                        amount = ((queue_item.updated_meals)*applicable_price*1.13).round
                        statement_descriptor = "WK PLN " + queue_item.updated_meals.to_s
                        if Stripe::Plan.create(id:id, amount:amount,currency:"CAD",interval:"week",interval_count:1, name:id, statement_descriptor: statement_descriptor)
                            plan_match = Subscription.create(weekly_meals:queue_item.updated_meals,stripe_plan_id:id,interval:"week",interval_count:1, price:applicable_price)

                            if (queue_item.updated_meals == current_customer.total_meals_per_week) && ((current_customer.interval.blank? ? "week" : current_customer.interval) == "week") && ((current_customer.interval_count.blank? ? 1 : current_customer.interval) == 1)
                                current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu)
                            else
                                if current_customer.stripe_subscription_id.blank?
                                    current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                    update_interval = nil
                                    update_interval_count = nil
                                    current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                                else
                                    subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                                    _current_period_end = subscription.current_period_end
                                    subscription.plan = plan_match.stripe_plan_id
                                    subscription.trial_end = _current_period_end
                                    subscription.prorate = false  
                                    if subscription.save                      
                                        current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                        update_interval = nil
                                        update_interval_count = nil
                                        current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                         
                                    end
                                end
                            end
                        end
                    else
                        if (queue_item.updated_meals == current_customer.total_meals_per_week) && ((current_customer.interval.blank? ? "week" : current_customer.interval) == "week") && ((current_customer.interval_count.blank? ? 1 : current_customer.interval) == 1)
                            current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                            update_interval = nil
                            update_interval_count = nil
                            current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                 
                        else
                            if current_customer.stripe_subscription_id.blank?
                                current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                            else
                                subscription = Stripe::Customer.retrieve(current_customer.stripe_customer_id).subscriptions.retrieve(current_customer.stripe_subscription_id)
                                _current_period_end = subscription.current_period_end
                                subscription.plan = plan_match.take.stripe_plan_id
                                subscription.trial_end = _current_period_end
                                subscription.prorate = false  
                                if subscription.save                      
                                    current_customer.update_attributes(regular_meals_on_monday:queue_item.updated_reg_mon, green_meals_on_monday:queue_item.updated_grn_mon, regular_meals_on_thursday: queue_item.updated_reg_thu, green_meals_on_thursday: queue_item.updated_grn_thu, total_meals_per_week:queue_item.updated_meals, number_of_green: queue_item.updated_grn_mon + queue_item.updated_grn_thu)
                                    update_interval = nil
                                    update_interval_count = nil
                                    current_customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                                end
                            end
                        end
                    end
                rescue => error
                    puts '---------------------------------------------------'
                    puts "something went wrong trying to change subscription during weekly task"
                    puts error.message
                    puts '---------------------------------------------------' 
                    CustomerMailer.rescued_error(current_customer,error.message).deliver
                else
                    if current_customer.user
                        current_customer.user.log_activity("System: subscription meal count updated to #{queue_item.updated_meals} meals per week")
                    end
                    queue_item.add_to_record
                    queue_item.destroy
                end
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
