class DailySnapshot < ActiveRecord::Base


    def self.take_snapshot
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        active_nonpaused_customers = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:current_pick_up_date)
        active_customers = Customer.where(active?: ["Yes","yes"])

        existing_date = DailySnapshot.retrieve_snapshot(Date.today)
        if existing_date
            existing_date.update_attributes(
                active_customers_including_pause: active_customers.length,
                active_customers_excluding_pause: active_nonpaused_customers.length,
                total_meals: MealStatistic.retrieve("total_meals") 
            )
        else
            date_info = DailySnapshot.new(date:Date.today)
            if date_info.save
                date_info.update_attributes(
                    active_customers_including_pause: active_customers.length,
                    active_customers_excluding_pause: active_nonpaused_customers.length,
                    total_meals: MealStatistic.retrieve("total_meals") 
                )
            end
        end
    end    

    def self.retrieve_snapshot(date=Date.today)
        date.to_date
        if DailySnapshot.where(date:date).length == 1
            DailySnapshot.where(date:date).take
        else
            nil
        end
    end

end
