class UserSessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    if @user = login(params[:email], params[:password])
      redirect_to(user_profile_path, notice: 'Login successful')
    else
      redirect_to(login_path, notice: 'Login failed')
    end
  end

  def destroy
    logout
    redirect_to(login_path, notice: 'Logged out')
  end
end