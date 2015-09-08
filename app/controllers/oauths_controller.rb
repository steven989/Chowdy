class OauthsController < ApplicationController
  skip_before_filter :require_login
  def oauth
        login_at(params[:provider],{state:params[:stripe_customer_id]})
  end

  def callback
    stripe_customer_id = params[:state]
    provider = auth_params[:provider]

    if @user = login_from(provider) #check if already signed up using facebook, if so then log in
      redirect_to user_profile_path, :notice => "Logged in from #{provider.titleize}!"
    else #if the user didn't sign up with facebook
      begin
        facebook_email = @user_hash[:user_info]["email"].downcase
        if User.where(email:facebook_email).length == 1 #if someone created an account without facebook, loggin in using Facebook still works
            @user = User.where(email:facebook_email).take

            auto_login(@user)
            redirect_to user_profile_path
        else #no user match
          stripe_customer_id = params[:state]
          if stripe_customer_id.blank? #if on the login page
            if Customer.where(email:facebook_email).length > 0
              flash[:login_error] = "Please use the link in your confirmation email to create an account first. If you did not receive the confirmation email, <a href='#{resend_sign_up_link_customer_request_path+"?email="+facebook_email}'>click here</a> to get the link sent to your email again"
              redirect_to login_path
            else
              flash[:login_error] = "Cannot find your subscription. You must <a href='http://chowdy.ca/signup'>sign up</a> for a subscription first to create an account"
              redirect_to login_path
            end
          else #if on the sign up page
              email = Customer.where(stripe_customer_id:stripe_customer_id).take.email 
              @user = create_from(provider)
              @user.update_attributes(stripe_customer_id: params[:state], email: email)

              begin
                @user.log_activity("Online profile created")
              rescue => error
                puts error.message
              else
                puts '---------------------------------------------------'
              end


              # NOTE: this is the place to add '@user.activate!' if you are using user_activation submodule

              reset_session # protect from session fixation attack
              auto_login(@user)
              redirect_to user_profile_path, :notice => "Logged in from #{provider.titleize}!"
          end
        end
      rescue => error
        flash[:login_error] = "An error has occurred while logging in with Facebook. Please email <a href='mailto:help@chowdy.ca?subject=Facebook%20sign%20up%20error%3A%20'>help@chowdy.ca</a>. Please reference the email address you used to sign up"
        puts '---------------------------------------------------'
        puts error.message
        puts '---------------------------------------------------'
        redirect_to login_path, :alert => "Failed to login from #{provider.titleize}!"
      end
    end
  end

  private
  def auth_params
    params.permit(:code, :provider)
  end

end
