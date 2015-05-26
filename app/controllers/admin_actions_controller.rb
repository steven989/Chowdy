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
        @hubs =  SystemSetting.where(setting:"hub").map {|hub| hub.setting_value} 

        respond_to do |format|
          format.html {
            render partial: 'individual_customer_edit'
          }      
        end 
    end

    def individual_customer_update
        @customer = Customer.where(id:params[:id]).take
        if params[:todo] == "info"
            @customer.update_attributes(individual_attributes_params)
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
                            subscription.plan = plan_match.stripe_plan_id
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
                        subscription.plan = plan_match.take.stripe_plan_id
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

        end
        redirect_to user_profile_path+"#customers"
    end

    private 

    def individual_attributes_params
        params.require(:customer).permit(:name,:phone_number,:notes,:delivery_address,:delivery_time,:special_delivery_instructions,:referral_code)
    end

end
