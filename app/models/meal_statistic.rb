class MealStatistic < ActiveRecord::Base
    def self.retrieve(stat="xxx")
        if MealStatistic.where(statistic:stat).length == 1
            stat_object = MealStatistic.where(statistic:stat).take
            if stat_object.statistic_type == "integer"
                stat_object.value_integer
            elsif stat_object.statistic_type == "string"
                stat_object.value_string
            elsif stat_object.statistic_type == "long_text"
                stat_object.value_long_text
            end
        else
            nil
        end
    end
end
