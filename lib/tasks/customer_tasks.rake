namespace :customers do
    desc 'push start date to the next next Monday'
    task :push_start_date, [:number_of_weeks] => [:environment] do |t, args|
        StartDate.first.update(start_date: Date.commercial(Date.today.year, args[:number_of_weeks].to_i+Date.today.cweek, 1))
    end

    desc 'update status information for customers restarting after pause'
    task :restart_status => [:environment] do
        Customer.where(paused?: "yes", pause_end_date: ['2015-05-03', '2015-05-04']).each do |customer|
            customer.update(paused?:'No', pause_end_date:nil,pause_cancel_request:nil)
        end
    end
end
