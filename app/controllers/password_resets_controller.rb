class PasswordResetsController < ApplicationController
skip_before_filter :require_login

  def create
    @user = User.find_by_email(params[:email])

    # This line sends an email to the user with instructions on how to reset their password (a url with a random token)
    if @user
      @user.deliver_reset_password_instructions! 
      flash[:status] = "success"
      message = "Instructions have been sent to your email."
    else
      message = "We could not find your email address. Please <a href='http://chowdy.ca/signup'>sign up</a> for a subscription."
    end

    # Tell the user instructions have been sent whether or not email was found.
    # This is to not leak information to attackers about which emails exist in the system.
    flash[:login_error] = message
    redirect_to login_path
  end

  def edit
    @token = params[:id]
    @user = User.load_from_reset_password_token(params[:id])

    if @user.blank?
      not_authenticated
      return
    end  
  end

  def update
    @token = params[:id]
    @user = User.load_from_reset_password_token(params[:id])

    if @user.blank?
      not_authenticated
      return
    end

    # the next line makes the password confirmation validation work
    @user.password_confirmation = params[:user][:password_confirmation]
    # the next line clears the temporary token and updates the password
    if @user.change_password!(params[:user][:password])
      flash[:login_error] = "Password successfully updated. Please log in"
      flash[:status] = "success"
      redirect_to login_path
    else
      render :action => "edit"
    end
  end
end
