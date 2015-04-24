class UsersController < ApplicationController
    
    def create
        @user = User.new(user_params)
        if @user.save
        end
    end

    def profile
        require_login

        @current_user = current_user

    end

    private

    def user_params
        params.require(:user).permit(:email,:password,:password_confirmation, :stripe_customer_id)
    end

    def require_login
        redirect_to login_path if !logged_in?
    end

end
