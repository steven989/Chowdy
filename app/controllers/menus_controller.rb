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

    def update        
        received_data = params[:data].to_a

        results = []

        received_data.each do |rd|
            production_day = rd[:production_day].to_date
            meal_name = rd[:meal_name]
            protein = rd[:protein]
            carb = rd[:carb]
            veggie = rd[:veggie]
            extra = rd[:extra]
            notes = rd[:notes]
            dish = rd[:dish]

            Menu.where(production_day:production_day).delete_all if Menu.where(production_day:production_day).length > 0
            menu_item = Menu.new(production_day:production_day,meal_name:meal_name,protein:protein,carb:carb,veggie:veggie,extra:extra,notes:notes,dish:dish)
            
            if menu_item.save
                results.push([production_day,true,nil])
            else
                results.push([production_day,false,menu_item.errors.full_messages.join(", ")])
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
