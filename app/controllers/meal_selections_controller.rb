class MealSelectionsController < ApplicationController

    def update

        begin

        current_customer = current_user.customer
        
        if current_customer.stop_queues.where(stop_type:'change_sub').limit(1).take.blank?
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

        if meal_selection[0]['beef'].to_i + meal_selection[0]['pork'].to_i + meal_selection[0]['poultry'].to_i < monday_regular
            status = "fail"
            message.push("Not enough regular meals selected for Monday")
        elsif meal_selection[0]['beef'].to_i + meal_selection[0]['pork'].to_i + meal_selection[0]['poultry'].to_i > monday_regular
            status = "fail"
            message.push("Regular meals selected for Monday is more than the subscribed amount. Please adjust your subscription amount in the 'Manage Subscriptions' tab")
        elsif meal_selection[0]['green_1'].to_i + meal_selection[0]['green_2'].to_i < monday_green
            status = "fail"
            message.push("Not enough green meals selected for Monday")
        elsif meal_selection[0]['green_1'].to_i + meal_selection[0]['green_2'].to_i > monday_green
            status = "fail"
            message.push("Green meals selected for Monday is more than the subscribed amount. Please change your green meal count in 'Manage Subscriptions' tab")
        elsif meal_selection[1]['beef'].to_i + meal_selection[1]['pork'].to_i + meal_selection[1]['poultry'].to_i < thursday_regular
            status = "fail"
            message.push("Not enough regular meals selected for Thursday")
        elsif meal_selection[1]['beef'].to_i + meal_selection[1]['pork'].to_i + meal_selection[1]['poultry'].to_i > thursday_regular
            status = "fail"
            message.push("Regular meals selected for Thursday is more than the subscribed amount. Please adjust your subscription amount in the 'Manage Subscriptions' tab")        
        elsif meal_selection[1]['green_1'].to_i + meal_selection[1]['green_2'].to_i < thursday_green
            status = "fail"
            message.push("Not enough green meals selected for Thursday")
        elsif meal_selection[1]['green_1'].to_i + meal_selection[1]['green_2'].to_i > thursday_green
            status = "fail"
            message.push("Green meals selected for Thursday is more than the subscribed amount. Please change your green meal count in 'Manage Subscriptions' tab")
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
                    green_2:ms['green_2'].to_i
                )

                meal_selections.push(result)
            end
        end

        rescue => error
            status = "fail"
            message.push(error.message)
        else
            CustomerMailer.delay.stop_delivery_notice(current_customer, "Meal selection has changed",meal_selections)
            if Date.today.wday == 0 && Date.today < current_customer.first_pick_up_date
                CustomerMailer.delay.urgent_stop_delivery_notice(current_customer, "Meal selection has changed",meal_selections)
            end
            status ||= "success"
        end

        respond_to do |format|
          format.json {
            render json: {status:status, message:message.join(". ")}
          }
        end   

    end

end
