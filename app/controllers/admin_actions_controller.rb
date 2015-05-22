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


end
