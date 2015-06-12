class ScheduledTask < ActiveRecord::Base
    # Chowdy::Application.load_tasks

    def self.run_all_tasks
        report = []

        sch_tasks = ScheduledTask.where{((day_of_week == Date.today.wday) & (hour_of_day == Time.now.hour)) | ((day_of_week == nil) & (hour_of_day == Time.now.hour)) }
        if sch_tasks.length > 0
            sch_tasks.each do |t|
                report.push(t.run)
            end
            CustomerMailer.scheduled_task_report(report).deliver
        else
            puts "No schedueld job right now"
        end 
    end

    def run
        begin
            if self.parameter_1.blank?
                Rake::Task[self.task_name].invoke
            else
                if self.parameter_2.blank?
                    parameter_1 = self.parameter_1_type == "int" ? self.parameter_1.to_i : self.parameter_1
                    Rake::Task[self.task_name].invoke(parameter_1)
                else 
                    if self.parameter_3.blank?
                        parameter_1 = self.parameter_1_type == "int" ? self.parameter_1.to_i : self.parameter_1
                        parameter_2 = self.parameter_2_type == "int" ? self.parameter_2.to_i : self.parameter_2
                        Rake::Task[self.task_name].invoke(parameter_1,parameter_2)
                    else 
                        parameter_1 = self.parameter_1_type == "int" ? self.parameter_1.to_i : self.parameter_1
                        parameter_2 = self.parameter_2_type == "int" ? self.parameter_2.to_i : self.parameter_2
                        parameter_3 = self.parameter_3_type == "int" ? self.parameter_3.to_i : self.parameter_3
                        Rake::Task[self.task_name].invoke(parameter_1,parameter_2,parameter_3)
                    end
                end
            end
        rescue
            self.update_attributes(last_attempt_date: Time.now)
            return_value = {self.task_name.to_sym => "fail"}
        else 
            self.update_attributes(last_successful_run: Time.now)
            self.update_attributes(last_attempt_date: Time.now)
            return_value = {self.task_name.to_sym => "success"}
        end
        return_value 
    end
end
