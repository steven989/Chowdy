class OauthsController < ApplicationController
  skip_before_filter :require_login
  def oauth
        login_at(params[:provider],{state:params[:stripe_customer_id]})
  end

  def callback
    stripe_customer_id = params[:state]
    provider = auth_params[:provider]

    if @user = login_from(provider)
      redirect_to user_profile_path, :notice => "Logged in from #{provider.titleize}!"
    else
      begin
        facebook_email = @user_hash[:user_info][:email].downcase

        puts '---------------------------------------------------'
        puts @user_hash.inspect
        puts facebook_email.inspect
        puts '---------------------------------------------------'
        if User.where(email:facebook_email).length == 1 #if someone created an account without facebook, loggin in using Facebook still works
            @user = User.where(email:facebook_email).take

            puts '---------------------------------------------------'
            puts @user.inspect
            puts '---------------------------------------------------'

            auto_login(@user)
            redirect_to user_profile_path
        else
          if Customer.where(email:facebook_email).length > 0
            flash[:login_error] = "Please use the link in your confirmation email to create an account. If you did not receive the confirmation email, <a href='#{resend_sign_up_link_customer_request_path+"?email="+facebook_email}'>click here</a> to get the link sent to your email again"
            redirect_to login_path
          else
              stripe_customer_id = params[:state]
              if 
                if stripe_customer_id.blank?
                    flash[:login_error] = "Cannot find your subscription. You must <a href='http://chowdy.ca/signup'>sign up</a> for a subscription first to create an account"
                    redirect_to login_path
                else
                    email = Customer.where(stripe_customer_id:stripe_customer_id).take.email 
                    @user = create_from(provider)
                    @user.update_attributes(stripe_customer_id: params[:state], email: email)
                    # NOTE: this is the place to add '@user.activate!' if you are using user_activation submodule

                    reset_session # protect from session fixation attack
                    auto_login(@user)
                    redirect_to user_profile_path, :notice => "Logged in from #{provider.titleize}!"
                end

            end

          end
        end
      rescue => error
        flash[:login_error] = "An error has occurred."
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
