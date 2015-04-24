class UsersController < ApplicationController
    
    def create
        @user = User.new(user_params)
        if @user.save
        end
    end

    def profile
        require_login

        @current_customer = current_user.customer
        current_period_end = Stripe::Customer.retrieve(@current_customer.stripe_customer_id).subscriptions.data[0].current_period_end
        @next_billing_date = Time.at(current_period_end).to_datetime + 2.hours
        if @current_customer.recurring_delivery?.blank?
            @delivery_note = "Delivery not requested"
        else 
            @delivery_note = "Delivery details"
        end
    
    end

    private

    def user_params
        params.require(:user).permit(:email,:password,:password_confirmation, :stripe_customer_id)
    end

    def require_login
        redirect_to login_path if !logged_in?
    end

end
