class AdminActionsController < ApplicationController

    def customer_sheet  
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        @current_period = current_pick_up_date.strftime("%b %d")+" - " +(current_pick_up_date+ 5.days).strftime("%b %d")
        @id_iterate = 1
        if params[:hub] == 'wandas'
            @location = "Wanda's"
            @location_match ='wanda'
            @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & ((monday_pickup_hub =~ '%wanda%') | (monday_delivery_hub =~ '%wanda%') | (thursday_pickup_hub =~ '%wanda%') | (thursday_delivery_hub =~ '%wanda%'))}.order("LOWER(name) asc")            
            
        elsif params[:hub] == 'coffee_bar'
            @location = "Coffee Bar"
            @location_match ='coffee'
            @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & ((monday_pickup_hub =~ '%coffee%bar%') | (monday_delivery_hub =~ '%coffee%bar%') | (thursday_pickup_hub =~ '%coffee%bar%') | (thursday_delivery_hub =~ '%coffee%bar%'))}.order("LOWER(name) asc")
        elsif params[:hub] == 'dekefir'
            @location = "deKEFIR"
            @location_match ='dekefir'
            @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & ((monday_pickup_hub =~ '%dekefir%') | (monday_delivery_hub =~ '%dekefir%') | (thursday_pickup_hub =~ '%dekefir%') | (thursday_delivery_hub =~ '%dekefir%'))}.order("LOWER(name) asc")
        end

        @data = [] 
        @customers.each do |c|
            @data.push({id: @id_iterate,name:c.name.titlecase,email:c.email,reg_mon: if c.monday_pickup_hub.match(/#{@location_match}/i) || c.monday_delivery_hub.match(/#{@location_match}/i); c.regular_meals_on_monday.to_i else 0 end, reg_thu: if c.thursday_pickup_hub.match(/#{@location_match}/i) || c.thursday_delivery_hub.match(/#{@location_match}/i); c.regular_meals_on_thursday.to_i else 0 end,grn_mon: if c.monday_pickup_hub.match(/#{@location_match}/i) || c.monday_delivery_hub.match(/#{@location_match}/i); c.green_meals_on_monday.to_i else 0 end, grn_thu: if c.thursday_pickup_hub.match(/#{@location_match}/i) || c.thursday_delivery_hub.match(/#{@location_match}/i); c.green_meals_on_thursday.to_i else 0 end})
            @id_iterate += 1
        end

        respond_to do |format|
            format.html
            format.csv { 
                puts '---------------------------------------------------'
                disposition = "attachment; filename='customer_sheet_#{params[:hub]}_#{StartDate.first.start_date.strftime("%Y_%m_%d")}'"
                puts disposition
                puts '---------------------------------------------------'
                response.headers['Content-Disposition'] = disposition
                if @data.blank?
                    send_data  CSV.generate {|csv| csv << ["id","name","email","reg_mon","reg_thu","grn_mon","grn_thu"]} 
                else 
                    send_data  CSV.generate {|csv| csv << @data.first.keys; @data.each {|data| csv << data.values} } 
                end
            }
        end

    end

    def next_week_breakdown
        @regular_monday = Customer.meal_count("regular_meals_next_monday")
        @green_monday = Customer.meal_count("green_meals_next_monday")
        @regular_thursday = Customer.meal_count("regular_meals_next_thursday")
        @green_thursday = Customer.meal_count("green_meals_next_thursday")
        @monday_wandas = Customer.meal_count("wandas_meals_next_monday")
        @thursday_wandas = Customer.meal_count("wandas_meals_next_thursday")
        @monday_coffee_bar = Customer.meal_count("coffee_bar_meals_next_monday")
        @thursday_coffee_bar = Customer.meal_count("coffee_bar_meals_next_thursday")
        @monday_dekefir = Customer.meal_count("dekefir_meals_next_monday")
        @thursday_dekefir = Customer.meal_count("dekefir_meals_next_thursday")
        @monday_unassigned = Customer.meal_count("hub_unassigned_meals_next_monday")
        @thursday_unassigned = Customer.meal_count("hub_unassigned_meals_next_thursday")

        @neg_adjustment_pork_next_monday = -Customer.meal_count("neg_adjustment_pork_next_monday").to_i
        @neg_adjustment_beef_next_monday = -Customer.meal_count("neg_adjustment_beef_next_monday").to_i
        @neg_adjustment_poultry_next_monday = -Customer.meal_count("neg_adjustment_poultry_next_monday").to_i

        @neg_adjustment_pork_next_thursday = -Customer.meal_count("neg_adjustment_pork_next_thursday").to_i
        @neg_adjustment_beef_next_thursday = -Customer.meal_count("neg_adjustment_beef_next_thursday").to_i
        @neg_adjustment_poultry_next_thursday = -Customer.meal_count("neg_adjustment_poultry_next_thursday").to_i        

        respond_to do |format|
          format.html {
            render partial: 'form'
          }      
        end  
    end

    def individual_customer_edit
        @customer = Customer.where(id:params[:id]).take
        @interval = @customer.interval.blank? ? "week" : @customer.interval
        @interval_count = @customer.interval_count.blank? ? 1 : @customer.interval_count
        @hubs =  SystemSetting.where(setting:"hub", setting_attribute: ["hub_1","hub_2","hub_3"]).map {|hub| hub.setting_value} 
        @meals_refunded_this_week = Refund.where(stripe_customer_id:@customer.stripe_customer_id, refund_week: SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date).group(:internal_refund_id).maximum(:meals_refunded).values.sum {|e| e}
        @amount_refunded_this_week = (Refund.where(stripe_customer_id:@customer.stripe_customer_id, refund_week: SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date).sum(:amount_refunded).to_f)/100.00
        @active_coupons = Promotion.where(active:true).map {|p| p.code }
        @cancel_reasons =  SystemSetting.where(setting:"cancel_reason").map {|reason| reason.setting_value}.push("Non-payment")
        @requests = @customer.formatted_request_queues

        respond_to do |format|
          format.html {
            render partial: 'individual_customer_edit'
          }      
        end 
    end

    def mark_failed_invoice_as_paid
        if invoice = FailedInvoice.where(id: params[:id]).take
            begin
                stripe_invoice = Stripe::Invoice.retrieve(invoice.invoice_number)
                stripe_invoice.closed = true
                stripe_invoice.save
            rescue Stripe::InvalidRequestError => error
                if error.message.scan(/paid/i).length > 0
                    invoice.update_attributes(paid:true, next_attempt:nil, date_paid: Date.today)
                else
                    puts '---------------------------------------------------'
                    puts 'Something went wrong trying to close an invoice'
                    puts error.message
                    puts '---------------------------------------------------'
                    CustomerMailer.delay.rescued_error(invoice.customer,'Something went wrong trying to close an invoice: '+error.message.inspect)
                end
            rescue => error
                puts '---------------------------------------------------'
                puts 'Something went wrong trying to close an invoice'
                puts error.message
                puts '---------------------------------------------------'
                CustomerMailer.delay.rescued_error(invoice.customer,'Something went wrong trying to close an invoice: '+error.message.inspect)
            else
                invoice.update_attributes(paid:true, next_attempt:nil, date_paid: Date.today)
            end
        end
        redirect_to user_profile_path+"#dashboard"
    end

    def individual_customer_update
        @customer = Customer.where(id:params[:id]).take
        _sponsor = @customer.sponsored? ? "1" : "0"
        if params[:todo] == "info"
            @customer.update_attributes(individual_attributes_params)
            if (params[:customer][:email] != @customer.email) && (!params[:customer][:email].blank?)
                begin
                    current_stripe_customer = Stripe::Customer.retrieve(@customer.stripe_customer_id)   
                    current_stripe_customer.email = params[:customer][:email]
                    current_stripe_customer.save
                rescue => error
                    puts '---------------------------------------------------'
                    puts "Email could not be updated"
                    puts '---------------------------------------------------'
                    CustomerMailer.delay.rescued_error(@customer,"Email could not be updated: "+error.message)
                else
                    if @customer.user
                        @customer.user.update(email:params[:customer][:email])
                    end
                    @customer.update(email:params[:customer][:email])
                end
            end

            if (params[:customer][:referral_code].gsub(" ","") != @customer.referral_code) && (!params[:customer][:referral_code].blank?)
                _old_referral_code = @customer.referral_code
                if @customer.update(referral_code:params[:customer][:referral_code].gsub(" ",""))
                    Customer.where(matched_referrers_code:_old_referral_code).each do |c|
                        c.update_attributes(matched_referrers_code:params[:customer][:referral_code].gsub(" ",""))
                    end
                end
            end

            if (params[:customer][:sponsored] != _sponsor) && (params[:customer][:sponsored] == "1")
                unless @customer.stripe_subscription_id.blank?
                    stripe_subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                    if stripe_subscription.delete
                        @customer.update_attributes(stripe_subscription_id:nil)
                    end
                end
            elsif (params[:customer][:sponsored] != _sponsor) && (params[:customer][:sponsored] == "0")
                if @customer.stripe_subscription_id.blank?
                    current_customer_interval = @customer.interval.blank? ? "week" : @customer.interval
                    current_customer_interval_count = @customer.interval_count.blank? ? 1 : @customer.interval_count
                    meals_per_week = Subscription.where(weekly_meals:@customer.total_meals_per_week, interval: current_customer_interval, interval_count:current_customer_interval_count).take.stripe_plan_id
                    
                    effective_date = StartDate.first.start_date

                    if Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:effective_date.to_time.to_i)                
                        new_subscription_id = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.all.data[0].id
                        @customer.update(stripe_subscription_id: new_subscription_id) 
                    end
                end
            end

            no_beef = (params[:customer][:no_beef].blank? || params[:customer][:no_beef] == "0") ? false : true
            no_pork = (params[:customer][:no_pork].blank? || params[:customer][:no_pork] == "0") ? false : true
            no_poultry = (params[:customer][:no_poultry].blank? || params[:customer][:no_poultry] == "0") ? false : true
            send_notification = (no_beef != @customer.no_beef) || (no_pork != @customer.no_pork) || (no_poultry != @customer.no_poultry)
            @customer.update_attributes(no_beef:no_beef,no_pork:no_pork,no_poultry:no_poultry)
            if (["Yes","yes"].include? @customer.recurring_delivery) && (send_notification)
                CustomerMailer.delay.stop_delivery_notice(@customer, "Meal preference has changed")
            end



        elsif params[:todo] == "meal_count"
            monday_regular = params[:customer][:regular_meals_on_monday].to_i
            monday_green = params[:customer][:green_meals_on_monday].to_i
            thursday_regular = params[:customer][:regular_meals_on_thursday].to_i
            thursday_green = params[:customer][:green_meals_on_thursday].to_i
            total_meals = monday_regular + monday_green + thursday_regular + thursday_green

            plan_match = Subscription.where(weekly_meals:total_meals, interval: params[:interval], interval_count:params[:interval_count].to_i)

            if plan_match.blank?
                id = total_meals.to_s+"meals"+(params[:interval_count].to_i > 1 ? params[:interval_count] : "")+params[:interval].gsub(/[aeioun]/i,"")
                amount = (total_meals*6.99*1.13*100).round
                statement_descriptor = (params[:interval_count].to_i > 1 ? params[:interval_count] : "") + params[:interval].gsub(/[aeioun]/i,"").upcase + " PLN " + total_meals.to_s
                if Stripe::Plan.create(id:id, amount:amount,currency:"CAD",interval:params[:interval],interval_count:params[:interval_count].to_i, name:id, statement_descriptor: statement_descriptor)
                    plan_match = Subscription.create(weekly_meals:total_meals,stripe_plan_id:id,interval:params[:interval],interval_count:params[:interval_count].to_i)

                    if (total_meals == @customer.total_meals_per_week) && (params[:interval] == (@customer.interval.blank? ? "week" : @customer.interval)) && (params[:interval_count].to_i == (@customer.interval_count.blank? ? 1 : @customer.interval))
                        @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green)
                    else
                        if @customer.stripe_subscription_id.blank?
                            @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green, total_meals_per_week:total_meals, number_of_green: monday_green + thursday_green)
                            update_interval = params[:interval] == "week" ? nil : params[:interval]
                            update_interval_count = params[:interval_count].to_i == 1 ? nil : params[:interval_count].to_i
                            @customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                        else
                            subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                            _current_period_end = subscription.current_period_end
                            subscription.plan = plan_match.stripe_plan_id
                            subscription.trial_end = _current_period_end
                            subscription.prorate = false  
                            if subscription.save                      
                                @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green, total_meals_per_week:total_meals, number_of_green: monday_green + thursday_green)
                                update_interval = params[:interval] == "week" ? nil : params[:interval]
                                update_interval_count = params[:interval_count].to_i == 1 ? nil : params[:interval_count].to_i
                                @customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                         
                            end
                        end
                    end
                end
            else
                if (total_meals == @customer.total_meals_per_week) && (params[:interval] == (@customer.interval.blank? ? "week" : @customer.interval)) && (params[:interval_count].to_i == (@customer.interval_count.blank? ? 1 : @customer.interval))
                    @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green, number_of_green: monday_green + thursday_green)
                    update_interval = params[:interval] == "week" ? nil : params[:interval]
                    update_interval_count = params[:interval_count].to_i == 1 ? nil : params[:interval_count].to_i
                    @customer.update_attributes(interval:update_interval, interval_count:update_interval_count)                 
                else
                    if @customer.stripe_subscription_id.blank?
                        @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green, total_meals_per_week:total_meals, number_of_green: monday_green + thursday_green)
                    else
                        subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                        _current_period_end = subscription.current_period_end
                        subscription.plan = plan_match.take.stripe_plan_id
                        subscription.trial_end = _current_period_end
                        subscription.prorate = false  
                        if subscription.save                      
                            @customer.update_attributes(regular_meals_on_monday:monday_regular, green_meals_on_monday:monday_green, regular_meals_on_thursday: thursday_regular, green_meals_on_thursday: thursday_green, total_meals_per_week:total_meals, number_of_green: monday_green + thursday_green)

                            update_interval = params[:interval] == "week" ? nil : params[:interval]
                            update_interval_count = params[:interval_count].to_i == 1 ? nil : params[:interval_count].to_i
                            @customer.update_attributes(interval:update_interval, interval_count:update_interval_count)
                      
                        end
                    end
                end
            end
        elsif params[:todo] == "hub"
            monday_pickup_hub = params[:customer][:monday_pickup_hub]
            thursday_pickup_hub = params[:customer][:thursday_pickup_hub]
            monday_delivery_hub = params[:customer][:monday_delivery_hub]
            thursday_delivery_hub = params[:customer][:thursday_delivery_hub]
            @customer.monday_pickup_hub = monday_pickup_hub unless monday_pickup_hub.blank?
            @customer.thursday_pickup_hub = thursday_pickup_hub unless thursday_pickup_hub.blank?
            @customer.monday_delivery_hub = monday_delivery_hub unless monday_delivery_hub.blank?
            @customer.thursday_delivery_hub = thursday_delivery_hub unless thursday_delivery_hub.blank?

            @customer.save

        elsif params[:todo] == "delivery_info"
            @customer.update_attributes(delivery_info_params)
            @customer.update_attribute(:delivery_set_up?,params[:customer][:delivery_set_up])
        elsif params[:todo] == "delivery_toggle"
            if ["Yes","yes"].include? @customer.recurring_delivery
                @customer.update_attributes(recurring_delivery: nil)
                CustomerMailer.delay.stop_delivery_notice(@customer, "Stop Delivery")
            else
                @customer.update_attributes(recurring_delivery: "yes")
                @customer.update_attributes(monday_delivery_hub: "delivery") if @customer.monday_delivery_hub.blank?
                @customer.update_attributes(thursday_delivery_hub: "delivery") if @customer.thursday_delivery_hub.blank?                
                @customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all
                CustomerMailer.delay.stop_delivery_notice(@customer, "Start Delivery")
            end
        elsif params[:todo] == "refund"
            recent_charges = Stripe::Charge.all(customer:@customer.stripe_customer_id, limit:20).data.inject([]) do |array, data| array.push(data.id) end
            amount = (params[:refund][:meals_refunded].to_i * 6.99 * 1.13 * 100).round
            refund_list = []
            recent_charges.each do |charge_id|
                charge = Stripe::Charge.retrieve(charge_id)
                net_amount = charge.amount - charge.amount_refunded
                if net_amount - amount >= 0
                    refund_list.push({charge_id.to_sym => amount})
                    break
                else
                    refund_list.push({charge_id.to_sym => net_amount}) unless net_amount == 0
                    amount -= net_amount
                end
            end

            refund_week = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
            internal_refund_id = nil
            refund_list.each do |refund_li|
                charge_id = refund_li.keys[0].to_s
                list_refund_amount = refund_li.values[0]
                charge = Stripe::Charge.retrieve(charge_id)
                if stripe_refund_response = charge.refunds.create(amount:list_refund_amount) 
                    newly_created_refund = Refund.create(stripe_customer_id: @customer.stripe_customer_id, refund_week:refund_week, charge_week:Time.at(charge.created).to_date,charge_id: charge.id, meals_refunded:params[:refund][:meals_refunded].to_i, amount_refunded: list_refund_amount, refund_reason: params[:refund][:refund_reason], stripe_refund_id: stripe_refund_response.id)
                    newly_created_refund.internal_refund_id = internal_refund_id.nil? ? newly_created_refund.id : internal_refund_id
                    if newly_created_refund.save
                        internal_refund_id ||= newly_created_refund.id
                    end
                end     

            end
        elsif params[:todo] == "attach_coupon"
            promotion = Promotion.where(code: params[:coupon_code]).take
            stripe_customer = Stripe::Customer.retrieve(@customer.stripe_customer_id)
            stripe_subscription = stripe_customer.subscriptions.retrieve(@customer.stripe_subscription_id)

            unless promotion.nil?
                if promotion.immediate_refund
                    recent_charges = Stripe::Charge.all(customer:@customer.stripe_customer_id, limit:20).data.inject([]) do |array, data| array.push(data.id) end
                    amount = promotion.amount_in_cents
                    refund_list = []
                    recent_charges.each do |charge_id|
                        charge = Stripe::Charge.retrieve(charge_id)
                        net_amount = charge.amount - charge.amount_refunded
                        if net_amount - amount >= 0
                            refund_list.push({charge_id.to_sym => amount})
                            break
                        else
                            refund_list.push({charge_id.to_sym => net_amount}) unless net_amount == 0
                            amount -= net_amount
                        end
                    end

                    refund_list.each do |refund_li|
                        charge_id = refund_li.keys[0].to_s
                        list_refund_amount = refund_li.values[0]
                        charge = Stripe::Charge.retrieve(charge_id)
                        charge.refunds.create(amount:list_refund_amount) 
                    end

                    promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
                else 
                    stripe_subscription.coupon = promotion.stripe_coupon_id
                    stripe_subscription.prorate = false
                    if stripe_subscription.save
                        promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
                    end
                end
            end

        elsif params[:todo] == "apply_referral"
            unless @customer.stripe_subscription_id.blank?
                stripe_customer = Stripe::Customer.retrieve(@customer.stripe_customer_id)
                stripe_subscription = stripe_customer.subscriptions.retrieve(@customer.stripe_subscription_id)

                referral = params[:referral_code]
                if Customer.where(referral_code: referral.gsub(" ","").downcase).length == 1 #match code
                    referral_match = Customer.where(referral_code: referral.gsub(" ","").downcase)
                    
                    unless referral_match.take.stripe_subscription_id.blank?
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
                            elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                stripe_referral_subscription_match.coupon = "referral bonus x 5"
                            else
                                do_not_increment_referral = true
                                CustomerMailer.delay.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)")
                            end

                        stripe_referral_subscription_match.prorate = false
                        if stripe_referral_subscription_match.save                
                            referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10) unless do_not_increment_referral
                        end
                    end
                    #referree discount
                    if stripe_subscription.discount.nil?
                        stripe_subscription.coupon = "referral bonus"
                    elsif stripe_subscription.discount.coupon.id == "referral bonus"
                        stripe_subscription.coupon = "referral bonus x 2"
                    elsif stripe_subscription.discount.coupon.id == "referral bonus x 2"
                        stripe_subscription.coupon = "referral bonus x 3"
                    elsif stripe_subscription.discount.coupon.id == "referral bonus x 3"
                        stripe_subscription.coupon = "referral bonus x 4"
                    elsif stripe_subscription.discount.coupon.id == "referral bonus x 4"
                        stripe_subscription.coupon = "referral bonus x 5"
                    else
                        do_not_increment_referral_referree = true
                        CustomerMailer.delay.rescued_error(@customer,"More referrals accrued than available in system (more than 5 referrals)")
                    end
                    stripe_subscription.prorate = false
                    if stripe_subscription.save
                        @customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: @customer.referral_bonus_referree.to_i + 10) unless do_not_increment_referral_referree
                    end
                
                else #match name
                    referral_match = Customer.where("name ilike ?", referral.gsub(/\s$/,"").downcase)
                    if referral_match.length == 1
                        
                        unless referral_match.take.stripe_subscription_id.blank?
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
                                elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                    stripe_referral_subscription_match.coupon = "referral bonus x 5"
                                else
                                    do_not_increment_referral = true
                                    CustomerMailer.delay.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)")
                                end

                            stripe_referral_subscription_match.prorate = false
                            if stripe_referral_subscription_match.save                
                                referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10) unless do_not_increment_referral
                            end
                        end             
                        #referree discount
                        if stripe_subscription.discount.nil?
                            stripe_subscription.coupon = "referral bonus"
                        elsif stripe_subscription.discount.coupon.id == "referral bonus"
                            stripe_subscription.coupon = "referral bonus x 2"
                        elsif stripe_subscription.discount.coupon.id == "referral bonus x 2"
                            stripe_subscription.coupon = "referral bonus x 3"
                        elsif stripe_subscription.discount.coupon.id == "referral bonus x 3"
                            stripe_subscription.coupon = "referral bonus x 4"
                        elsif stripe_subscription.discount.coupon.id == "referral bonus x 4"
                            stripe_subscription.coupon = "referral bonus x 5"
                        else
                            do_not_increment_referral_referree = true
                            CustomerMailer.delay.rescued_error(@customer,"More referrals accrued than available in system (more than 5 referrals)")
                        end

                        stripe_subscription.prorate = false
                        if stripe_subscription.save
                            @customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: @customer.referral_bonus_referree.to_i + 10) unless do_not_increment_referral_referree
                        end
                    end
                end
            end
        elsif params[:todo] == "stop" 
            if params[:stop_type].downcase == "pause" 
                end_date = params[:pause_end].to_date  
                if params[:immediate_effect] == "1"
                    unless end_date.blank?
                        adjusted_pause_end_date = Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                        if @customer.stripe_subscription_id.blank?
                            @customer.update(paused?:"yes", pause_end_date:adjusted_pause_end_date-1, next_pick_up_date:adjusted_pause_end_date)
                            @customer.stop_requests.create(request_type:'pause',start_date:Date.today, end_date:adjusted_pause_end_date-1, requested_date: Date.today)
                            @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                        else
                            stripe_subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                            stripe_subscription.trial_end = adjusted_pause_end_date.to_time.to_i
                            stripe_subscription.prorate = false
                            if stripe_subscription.save
                                @customer.update(paused?:"yes", pause_end_date:adjusted_pause_end_date-1, next_pick_up_date:adjusted_pause_end_date)
                                @customer.stop_requests.create(request_type:'pause',start_date:Date.today, end_date:adjusted_pause_end_date-1, requested_date: Date.today)
                                @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                            end
                        end
                    end
                else
                    associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                    unless end_date.blank?
                        adjusted_pause_end_date = Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                        if [2,3,4].include? Date.today.wday
                            adjusted_pause_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                        else
                            adjusted_pause_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                        end
                        if (adjusted_pause_end_date > adjusted_pause_start_date) && (["Yes","yes"].include? @customer.active?) && !(["Yes","yes"].include? @customer.paused?)
                            @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                            @customer.stop_queues.create(stop_type:'pause',associated_cutoff:associated_cutoff, end_date:adjusted_pause_end_date, start_date:adjusted_pause_start_date)
                        end
                    end
                end
            elsif params[:stop_type].downcase == "cancel"    
                if params[:immediate_effect] == "1"
                    if @customer.stripe_subscription_id.blank?
                        @customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                        @customer.stop_requests.create(request_type:'cancel',start_date:Date.today,cancel_reason:params[:cancel_reason], requested_date: Date.today)                      
                        @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                    else
                        stripe_subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                        if stripe_subscription.delete
                            @customer.update(paused?:nil, pause_end_date:nil, next_pick_up_date:nil, active?:"No", stripe_subscription_id: nil)
                            @customer.stop_requests.create(request_type:'cancel',start_date:Date.today,cancel_reason:params[:cancel_reason], requested_date: Date.today)
                            @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                        end
                    end
                else
                    if [2,3,4].include? Date.today.wday
                        adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                    else
                        adjusted_cancel_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                    end
                    associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                    if ["Yes","yes"].include? @customer.active?
                        @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                        @customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:params[:cancel_reason])
                    else
                        @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                    end
                end
            elsif params[:stop_type].downcase == "restart"
                if params[:immediate_effect] == "1"
                    if @customer.stripe_subscription_id.blank?
                        start_date_update = Chowdy::Application.closest_date(1,1)
                        if @customer.sponsored?
                            @customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil,pause_cancel_request:nil) 
                            @customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1)                       
                            @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                        else
                            current_customer_interval = @customer.interval.blank? ? "week" : @customer.interval
                            current_customer_interval_count = @customer.interval_count.blank? ? 1 : @customer.interval_count
                            meals_per_week = Subscription.where(weekly_meals:@customer.total_meals_per_week, interval: current_customer_interval, interval_count:current_customer_interval_count).take.stripe_plan_id
                            
                            if Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.create(plan:meals_per_week,trial_end:start_date_update.to_time.to_i)
                                new_subscription_id = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.all.data[0].id
                                @customer.update(next_pick_up_date:start_date_update, active?:"Yes", paused?:nil, stripe_subscription_id: new_subscription_id,pause_cancel_request:nil) 
                                @customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1)
                                @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                            end
                        end
                    else 
                        start_date_update = Chowdy::Application.closest_date(1,1)
                        paused_subscription = Stripe::Customer.retrieve(@customer.stripe_customer_id).subscriptions.retrieve(@customer.stripe_subscription_id)
                        paused_subscription.trial_end = start_date_update.to_time.to_i
                        paused_subscription.prorate = false
                        if paused_subscription.save
                            @customer.update(next_pick_up_date:start_date_update, paused?:nil, pause_end_date:nil,pause_cancel_request:nil)
                            @customer.stop_requests.order(created_at: :desc).limit(1).take.update(end_date: start_date_update-1)
                            @customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                        end
                    end
                else
                    if [2,3,4].include? Date.today.wday
                        adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                    else
                        adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                    end
                    associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                    
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
                end
            end
        elsif params[:todo] == "destroy" 
            @customer.delete_with_stripe
        end
        redirect_to user_profile_path+"#customers"
    end

    private 

    def individual_attributes_params
        params.require(:customer).permit(:name,:next_pick_up_date,:phone_number,:notes,:delivery_address,:delivery_time,:special_delivery_instructions, :sponsored)
    end

    def delivery_info_params
        params.require(:customer).permit(:delivery_address,:delivery_time, :special_delivery_instructions)
    end

end
