require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'csv'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chowdy
  class Application < Rails::Application
    require 'ext/nil.rb'
    config.assets.paths << Rails.root.join("app", "assets", "fonts")
    config.time_zone = 'Eastern Time (US & Canada)'
    config.active_job.queue_adapter = :delayed_job
    config.action_dispatch.default_headers = {
        'X-Frame-Options' => 'ALLOWALL'
        }
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
  
    def closest_date(distance=0,day_of_week=0, reference_date=Date.today)
        #distance specifies how many weeks away the desired day is from today. 1 indicates the upcoming, -1 indicates the last
        #day_of_week is from 1 to 7, where 1 is Monday and 7 is Sunday
        days_away = day_of_week - reference_date.to_date.wday
        
        if days_away > 0
            if distance.to_i > 0
                adjusted_distance = distance.to_i - 1
                reference_date.to_date + days_away + adjusted_distance * 7
            elsif distance.to_i < 0
                adjusted_distance = distance.to_i
                reference_date.to_date + days_away + adjusted_distance * 7
            else
                reference_date.to_date
            end  
        elsif days_away < 0
            if distance.to_i > 0
                adjusted_distance = distance.to_i
                reference_date.to_date + days_away + adjusted_distance * 7
            elsif distance.to_i < 0
                adjusted_distance = distance.to_i + 1
                reference_date.to_date + days_away + adjusted_distance * 7
            else
                reference_date.to_date
            end  
        else 
            if distance.to_i > 0
                adjusted_distance = distance.to_i
                reference_date.to_date + days_away + adjusted_distance * 7
            elsif distance.to_i < 0
                adjusted_distance = distance.to_i
                reference_date.to_date + days_away + adjusted_distance * 7
            else
                reference_date.to_date
            end  
        end 
    
    end

  end
end
