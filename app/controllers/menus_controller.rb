class MenusController < ApplicationController

    def show
        month = params[:id].to_i
        match_result = Menu.where("extract(month from production_day) = ?",month)
        respond_to do |format|
          format.json {
            render json: match_result.to_json
          }
        end
    end

    def pull_rating_details
        menu = Menu.find(params[:id])
        details = menu.menu_ratings.order(created_at: :desc)
        respond_to do |format|
          format.json {
            render json: details.to_json
          }
        end
    end

    def pull_suggestion
        category = params[:category]
        suggestions = Menu.where("meal_type ilike ? and meal_name !=''", "%#{category}%").order(average_score: :desc).limit(20).map{|mi| {meal_type:category.capitalize,data:[{id:mi.id,name:mi.meal_name,veg:mi.veggie,carb:mi.carb,rating:mi.average_score,last_made:mi.production_day}]}}
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
            dish = rd[:dish]

            if Menu.where(production_day:production_day,meal_type:meal_type).length > 0
                menu_item = Menu.where(production_day:production_day,meal_type:meal_type).take
                menu_item.update_attributes(production_day:production_day,meal_type:meal_type,meal_count:meal_count,meal_name:meal_name,protein:protein,carb:carb,veggie:veggie,extra:extra,notes:notes,dish:dish)
            else
                menu_item = Menu.new(production_day:production_day,meal_type:meal_type,meal_count:meal_count,meal_name:meal_name,protein:protein,carb:carb,veggie:veggie,extra:extra,notes:notes,dish:dish)
            
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

end
