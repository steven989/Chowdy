class MealSelectionsController < ApplicationController

    def update

        begin

        current_customer = current_user.customer
        
        if current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.blank? || ((Date.today < current_customer.first_pick_up_date && current_customer.created_at > Chowdy::Application.closest_date(-1,3,current_customer.first_pick_up_date) ) ? true : false)
            total_meals = current_customer.total_meals_per_week.to_i
            total_green = current_customer.number_of_green.to_i
            monday_regular = current_customer.regular_meals_on_monday.to_i
            monday_green = current_customer.green_meals_on_monday.to_i
            thursday_regular = current_customer.regular_meals_on_thursday.to_i
            thursday_green = current_customer.green_meals_on_thursday.to_i
        else
            total_meals = current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_meals.to_i
            monday_regular = current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_mon.to_i
            monday_green = current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_mon.to_i
            thursday_regular = current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_reg_thu.to_i
            thursday_green = current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.updated_grn_thu.to_i
            total_green = monday_green + thursday_green
        end

        meal_selection = JSON.parse(params[:meal_selection])


        message = []
        meal_selections = []

        if meal_selection[0]['beef'].to_i + meal_selection[0]['pork'].to_i + meal_selection[0]['poultry'].to_i + meal_selection[0]['salad_bowl_1'].to_i + meal_selection[0]['salad_bowl_2'].to_i + meal_selection[0]['diet'].to_i + meal_selection[0]['chefs_special'].to_i + meal_selection[0]['green_1'].to_i + meal_selection[0]['green_2'].to_i < monday_regular.to_i + monday_green.to_i
            status = "fail"
            message.push("Not enough meals selected for Monday")
        elsif meal_selection[0]['beef'].to_i + meal_selection[0]['pork'].to_i + meal_selection[0]['poultry'].to_i + meal_selection[0]['salad_bowl_1'].to_i + meal_selection[0]['salad_bowl_2'].to_i + meal_selection[0]['diet'].to_i + meal_selection[0]['chefs_special'].to_i + meal_selection[0]['green_1'].to_i + meal_selection[0]['green_2'].to_i > monday_regular.to_i + monday_green.to_i
            status = "fail"
            message.push("Meals selected for Monday is more than the subscribed amount. Please adjust your subscription amount in the 'Manage Subscriptions' tab")            
        elsif meal_selection[1]['beef'].to_i + meal_selection[1]['pork'].to_i + meal_selection[1]['poultry'].to_i + meal_selection[1]['salad_bowl_1'].to_i + meal_selection[1]['salad_bowl_2'].to_i + meal_selection[1]['diet'].to_i + meal_selection[1]['chefs_special'].to_i + meal_selection[1]['green_1'].to_i + meal_selection[1]['green_2'].to_i < thursday_regular.to_i + thursday_green.to_i 
            status = "fail"
            message.push("Not enough meals selected for Thursday")
        elsif meal_selection[1]['beef'].to_i + meal_selection[1]['pork'].to_i + meal_selection[1]['poultry'].to_i + meal_selection[1]['salad_bowl_1'].to_i + meal_selection[1]['salad_bowl_2'].to_i + meal_selection[1]['diet'].to_i + meal_selection[1]['chefs_special'].to_i + meal_selection[1]['green_1'].to_i + meal_selection[1]['green_2'].to_i > thursday_regular.to_i + thursday_green.to_i 
            status = "fail"
            message.push("Meals selected for Thursday is more than the subscribed amount. Please adjust your subscription amount in the 'Manage Subscriptions' tab")            
        else
            meal_selection.each do |ms|
                MealSelection.where(stripe_customer_id:current_customer.stripe_customer_id,production_day:ms['production_day'].to_date).delete_all
                result = MealSelection.create(
                    stripe_customer_id:current_user.customer.stripe_customer_id,
                    production_day:ms['production_day'].to_date,
                    beef:ms['beef'].to_i,
                    pork:ms['pork'].to_i,
                    poultry:ms['poultry'].to_i,
                    green_1:ms['green_1'].to_i,
                    green_2:ms['green_2'].to_i,
                    salad_bowl_1:ms['salad_bowl_1'].to_i,
                    salad_bowl_2:ms['salad_bowl_2'].to_i,
                    diet:ms['diet'].to_i,
                    chefs_special:ms['chefs_special'].to_i
                )

                meal_selections.push(result)
            end
        end

        rescue => error
            status = "fail"
            message.push(error.message)
        else
            unless status == "fail"
                if Date.today.wday == 0 && DateTime.now.hour < 14 && Date.today < current_customer.first_pick_up_date
                    CustomerMailer.delay.stop_delivery_notice(current_customer, "Meal selection has changed",meal_selections)
                    CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Meal selection has changed",meal_selections)
                end
                status = "success"
                current_user.log_activity("Meal selection for week of #{meal_selection[0]['production_day'].to_date}")
            end
        end

        respond_to do |format|
          format.json {
            render json: {status:status, message:message.join(". ")}
          }
        end   

    end


    def view_selection
        week_date = params[:week_date].to_date
        production_day_1 = Chowdy::Application.closest_date(-1,7,week_date)
        selections_production_day_1 = current_user.customer.meal_selections.where(production_day:production_day_1).take
        production_day_2 = Chowdy::Application.closest_date(1,3,week_date)
        selections_production_day_2 = current_user.customer.meal_selections.where(production_day:production_day_2).take

        @show_additional_menu_to_customers = SystemSetting.where(setting:"meal_selection",setting_attribute:"show_additional_menu").blank? ? false : (SystemSetting.where(setting:"meal_selection",setting_attribute:"show_additional_menu").take.setting_value == "true" ? true : false)

        @date = Chowdy::Application.closest_date(1,1,production_day_1).strftime("%B %e")
        if !selections_production_day_1.blank? && !selections_production_day_2.blank?
            if @show_additional_menu_to_customers
                @selection = {
                    meals_production_day_1: {
                        beef:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Beef").take.meal_name,number:selections_production_day_1.beef},
                        pork:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Pork").take.meal_name,number:selections_production_day_1.pork},
                        poultry:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Poultry").take.meal_name,number:selections_production_day_1.poultry},
                        green_1:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Green 1").take.meal_name,number:selections_production_day_1.green_1},
                        green_2:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Green 2").take.meal_name,number:selections_production_day_1.green_2},
                        salad_bowl_1:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Salad Bowl 1").take.meal_name,number:selections_production_day_1.salad_bowl_1},
                        salad_bowl_2:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Salad Bowl 2").take.meal_name,number:selections_production_day_1.salad_bowl_2},
                        diet:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Diet").take.meal_name,number:selections_production_day_1.diet},
                        chefs_special:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Chef's Special").take.meal_name,number:selections_production_day_1.chefs_special}
                    
                    },

                    meals_production_day_2: {
                        beef:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Beef").take.meal_name,number:selections_production_day_2.beef},
                        pork:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Pork").take.meal_name,number:selections_production_day_2.pork},
                        poultry:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Poultry").take.meal_name,number:selections_production_day_2.poultry},
                        green_1:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Green 1").take.meal_name,number:selections_production_day_2.green_1},
                        green_2:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Green 2").take.meal_name,number:selections_production_day_2.green_2},
                        salad_bowl_1:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Salad Bowl 1").take.meal_name,number:selections_production_day_2.salad_bowl_1},
                        salad_bowl_2:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Salad Bowl 2").take.meal_name,number:selections_production_day_2.salad_bowl_2},
                        diet:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Diet").take.meal_name,number:selections_production_day_2.diet},
                        chefs_special:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Chef's Special").take.meal_name,number:selections_production_day_2.chefs_special}
                    }
                }
            else
                @selection = {
                    meals_production_day_1: {
                        beef:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Beef").take.meal_name,number:selections_production_day_1.beef},
                        pork:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Pork").take.meal_name,number:selections_production_day_1.pork},
                        poultry:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Poultry").take.meal_name,number:selections_production_day_1.poultry},
                        green_1:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Green 1").take.meal_name,number:selections_production_day_1.green_1},
                        green_2:{meal_name:Menu.where(production_day:production_day_1,meal_type:"Green 2").take.meal_name,number:selections_production_day_1.green_2}
                    
                    },

                    meals_production_day_2: {
                        beef:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Beef").take.meal_name,number:selections_production_day_2.beef},
                        pork:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Pork").take.meal_name,number:selections_production_day_2.pork},
                        poultry:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Poultry").take.meal_name,number:selections_production_day_2.poultry},
                        green_1:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Green 1").take.meal_name,number:selections_production_day_2.green_1},
                        green_2:{meal_name:Menu.where(production_day:production_day_2,meal_type:"Green 2").take.meal_name,number:selections_production_day_2.green_2}
                    }
                }

            end
        else 
            @selection = nil
        end

        respond_to do |format|
          format.html {
            render partial: 'view_selection'
          }      
        end 

    end

end
