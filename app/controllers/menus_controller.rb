class MenusController < ApplicationController

    def show
        month = params[:id].to_i
        year = params[:year].to_i
        match_result = Menu.where("extract(year from production_day) = ? and extract(month from production_day) = ?",year,month)
        respond_to do |format|
          format.json {
            render json: match_result.to_json
          }
        end
    end

    def copied_menu_nutritional_update
        received_data = params[:data].to_hash

        current_menu_id = received_data['current_menu_id'].to_i
        current_menu = Menu.find(current_menu_id)
        current_menu_nutritional_info = current_menu.nutritional_info
        
        copied_menu_id = received_data['copied_menu_id'].to_i
        copied_menu = Menu.find(copied_menu_id)
        copied_menu_nutritional_info = copied_menu.nutritional_info

        overall_status = true
        overall_errors = []

        unless copied_menu_nutritional_info.blank?
            if current_menu_nutritional_info.blank?
                created_nutritional_info = current_menu.build_nutritional_info(protein:copied_menu_nutritional_info.protein,carb:copied_menu_nutritional_info.carb,fat:copied_menu_nutritional_info.fat,calories:copied_menu_nutritional_info.calories,allergen:copied_menu_nutritional_info.allergen,fiber:copied_menu_nutritional_info.fiber,spicy:copied_menu_nutritional_info.spicy)
                if created_nutritional_info.save
                    overall_status = true
                else
                    overall_status = false
                    overall_errors = [created_nutritional_info.errors.full_messages.join(", ")]
                end
            else
                created_nutritional_info = current_menu.nutritional_info
                created_nutritional_info.assign_attributes(protein:copied_menu_nutritional_info.protein,carb:copied_menu_nutritional_info.carb,fat:copied_menu_nutritional_info.fat,calories:copied_menu_nutritional_info.calories,allergen:copied_menu_nutritional_info.allergen,fiber:copied_menu_nutritional_info.fiber,spicy:copied_menu_nutritional_info.spicy)
                if created_nutritional_info.save
                    overall_status = true
                else
                    overall_status = false
                    overall_errors = [created_nutritional_info.errors.full_messages.join(", ")]
                end
            end
        end
        respond_to do |format|
          format.json {
            render json: {result: overall_status, errors: overall_errors.join(", ")}
          }
        end        
    end

    def pull_rating_details
        menu = Menu.find(params[:id])
        details = menu.menu_ratings.order(created_at: :desc).map {|mr| {menu_id:mr.menu_id, id:mr.id, customer_name: "#{mr.customer.name if mr.customer} (#{mr.customer.email if mr.customer})",rating:mr.rating,comment:mr.comment }}
        respond_to do |format|
          format.json {
            render json: details.to_json
          }
        end
    end

    def pull_suggestion
        category = params[:category]
        suggestions_no_null = Menu.where("meal_type ilike ? and meal_name !='' and average_score is not null", "%#{category}%").order(average_score: :desc).limit(30)
        set_limit = [30 - suggestions_no_null.length, 0].max
        suggestions_null = Menu.where("meal_type ilike ? and meal_name !='' and average_score is null", "%#{category}%").order(average_score: :desc).limit(set_limit)
        suggestions_combined = suggestions_no_null + suggestions_null
        suggestions = suggestions_combined.map{|mi| {meal_type:category.capitalize,data:[{id:mi.id,name:mi.meal_name,veg:mi.veggie,carb:mi.carb,rating:mi.average_score,last_made:mi.production_day}]}}

        respond_to do |format|
          format.json {
            render json: suggestions.to_json
          }
        end        
    end

    def pull_individual_detail
        menu_item = Menu.find(params[:meal_id])
        respond_to do |format|
          format.json {
            render json: menu_item.to_json
          }
        end
    end

    def update        
        received_data = params[:data].to_a

        results = []

        received_data.each do |rd|
            production_day = rd[:production_day].to_date
            meal_type = rd[:meal_type]
            meal_count = rd[:meal_count]
            meal_name = rd[:meal_name]
            protein = rd[:protein]
            carb = rd[:carb]
            veggie = rd[:veggie]
            extra = rd[:extra]
            notes = rd[:notes]
            no_microwave = rd[:no_microwave]

            if Menu.where(production_day:production_day,meal_type:meal_type).length > 0
                menu_item = Menu.where(production_day:production_day,meal_type:meal_type).take
                menu_item.update_attributes(production_day:production_day,meal_type:meal_type,meal_count:meal_count,meal_name:meal_name,protein:protein,carb:carb,veggie:veggie,extra:extra,notes:notes,no_microwave:no_microwave)
            else
                menu_item = Menu.new(production_day:production_day,meal_type:meal_type,meal_count:meal_count,meal_name:meal_name,protein:protein,carb:carb,veggie:veggie,extra:extra,notes:notes,no_microwave:no_microwave)
            
                if menu_item.save
                    results.push([production_day,true,nil])
                else
                    results.push([production_day,false,menu_item.errors.full_messages.join(", ")])
                end
            end
        end

        overall_errors = results.select {|r| r[1] == false}
        overall_status = overall_errors.length > 0 ? false : true

        respond_to do |format|
          format.json {
            render json: {result: overall_status, errors: overall_errors.join(", ")}
          }
        end
        
    end

    def edit_nutritional_info
        @menu_item = Menu.find(params[:id].to_i)
        @nutritional_info = @menu_item.nutritional_info.blank? ? @menu_item.build_nutritional_info : @menu_item.nutritional_info

        respond_to do |format|
          format.html {
            render partial: 'edit_nutritional_info'
          }      
        end 
    end

    def update_nutritional_info
        menu_item = Menu.find(params[:id].to_i)
        if menu_item.nutritional_info.blank?
            nutrition = menu_item.build_nutritional_info(nutritional_info_params)
            if nutrition.save
                overall_status = true
                overall_errors = []
            else
                overall_status = false
                overall_errors = [nutrition.errors.full_messages.join(", ")]
            end
        else
            nutrition = menu_item.nutritional_info
            nutrition.assign_attributes(nutritional_info_params)
            if nutrition.save
                overall_status = true
                overall_errors = []
            else
                overall_status = false
                overall_errors = [nutrition.errors.full_messages.join(", ")]
            end
        end

        respond_to do |format|
          format.json {
            render json: {result: overall_status, errors: overall_errors.join(", ")}
          }
        end
    end

    def show_nutritional_info
        menu_item = Menu.where(id:params[:id])
        @nutritional_info = menu_item.take.nutritional_info unless menu_item.blank?

        respond_to do |format|
          format.html {
            render partial: 'show_nutritional_info'
          }      
        end         
    end

    private

    def nutritional_info_params
        params.require(:nutritional_info).permit(:protein,:carb,:fat,:calories,:allergen,:fiber,:spicy)
    end


end
