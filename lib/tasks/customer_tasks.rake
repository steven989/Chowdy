namespace :customers do
    desc 'push start date to the next next Monday'
    task :push_start_date, [:number_of_weeks] => [:environment] do |t, args|
        StartDate.first.update(start_date: Date.commercial(Date.today.year, args[:number_of_weeks].to_i+Date.today.cweek, 1))
    end

    

end
