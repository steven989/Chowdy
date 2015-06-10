class UserSessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    if @user = login(params[:email].downcase, params[:password])
      redirect_to(user_profile_path, notice: 'Login successful')
    else
      if User.where(email:params[:email].downcase).length == 1
        if User.where(email:params[:email].downcase).take.facebook_email.blank?
          flash[:login_error] = "Incorrect email or password entered. Please try again."
        else 
          flash[:login_error] = "Please log in with Facebook"
        end
      else
        if Customer.where(email:params[:email].downcase).length > 0
          flash[:login_error] = "Please use the link in your confirmation email to create an account. If you do not have the email, <a href='#{resend_sign_up_link_customer_request_path+"?email="+params[:email].downcase}'>click here</a> to get the link to your email again."
        else
          flash[:login_error] = "Incorrect email or password entered. Please try again."
        end
      end
      redirect_to login_path
    end
  end

  def destroy
    logout
    redirect_to(login_path, notice: 'Logged out')
  end
end