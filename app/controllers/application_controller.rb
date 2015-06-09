class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  
  def default_url_options
    if Rails.env.production?
      {host: "http://members.chowdy.ca"}
    else  
      {host: "localhost:3000"}
    end
  end

  protect_from_forgery with: :exception

end
