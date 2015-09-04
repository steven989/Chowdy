class MealSelectionsController < ApplicationController

    def edit
        current_customer = current_user.customer
        cut_off_wday = SystemSetting.where(setting:'meal_selection', setting_attribute:'cut_off_week_day').take.setting_value.to_i
        display_production_day_1 = Chowdy::Application.wday(Date.today) <= cut_off_wday ? ( Chowdy::Application.wday(Date.today) == 7 ? Chowdy::Application.wday(Date.today) : Chowdy::Application.closest_date(1,7)) : (Chowdy::Application.wday(Date.today) == 7 ? Chowdy::Application.closest_date(1,7) : Chowdy::Application.closest_date(2,7))
        display_production_day_2 = Chowdy::Application.wday(Date.today) <= cut_off_wday ? ( Chowdy::Application.wday(Date.today) < 3 ? Chowdy::Application.closest_date(2,3) : Chowdy::Application.closest_date(1,3)) : (Chowdy::Application.wday(Date.today) < 3  ? Chowdy::Application.closest_date(3,3) : Chowdy::Application.closest_date(2,3))

        @selection_production_day_1 = MealSelection.where(stripe_customer_id:current_customer.stripe_customer_id,production_day:display_production_day_1).take
        @selection_production_day_2 = MealSelection.where(stripe_customer_id:current_customer.stripe_customer_id,production_day:display_production_day_2).take

        @pork_production_day_1 = Menu.where(production_day:display_production_day_1.to_date,meal_type:"Pork").take
        @beef_production_day_1 = Menu.where(production_day:display_production_day_1.to_date,meal_type:"Beef").take
        @poultry_production_day_1 = Menu.where(production_day:display_production_day_1.to_date,meal_type:"Poultry").take
        @green_1_production_day_1 = Menu.where(production_day:display_production_day_1.to_date,meal_type:"Green 1").take
        @green_2_production_day_1 = Menu.where(production_day:display_production_day_1.to_date,meal_type:"Green 2").take

        @pork_production_day_2 = Menu.where(production_day:display_production_day_2.to_date,meal_type:"Pork").take
        @beef_production_day_2 = Menu.where(production_day:display_production_day_2.to_date,meal_type:"Beef").take
        @poultry_production_day_2 = Menu.where(production_day:display_production_day_2.to_date,meal_type:"Poultry").take
        @green_1_production_day_2 = Menu.where(production_day:display_production_day_2.to_date,meal_type:"Green 1").take
        @green_2_production_day_2 = Menu.where(production_day:display_production_day_2.to_date,meal_type:"Green 2").take

        respond_to do |format|
          format.html {
            render partial: 'edit'
          }      
        end   
    end

    def update
        
    end
end
