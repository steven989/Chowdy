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
        stripe_customer_id = params[:state]
        if stripe_customer_id.blank?
            redirect_to login_path, :alert => "You must first sign up for your subscription first at chowdy.ca/signup"
        else
            email = Customer.where(stripe_customer_id:stripe_customer_id).take.email 
            @user = create_from(provider)
            @user.update_attributes(stripe_customer_id: params[:state], email: email)
            # NOTE: this is the place to add '@user.activate!' if you are using user_activation submodule

            reset_session # protect from session fixation attack
            auto_login(@user)
            redirect_to user_profile_path, :notice => "Logged in from #{provider.titleize}!"
        end
      rescue
        redirect_to login_path, :alert => "Failed to login from #{provider.titleize}!"
      end
    end
  end

  private
  def auth_params
    params.permit(:code, :provider)
  end

end
