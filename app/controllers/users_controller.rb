class UsersController < ApplicationController
    
    def create
        @user = User.new(user_params)
        if @user.save
            auto_login(@user)
            redirect_to user_profile_path
        else
            redirect_to create_customer_profile_path(@user.stripe_customer_id)
        end
    end

    def profile
        require_login

        @current_customer = current_user.customer

        if @current_customer.active?.downcase == "yes" 
            if @current_customer.paused?.blank? || @current_customer.paused? == "No" || @current_customer.paused? == "no"
                if @current_customer.stop_queues.length > 0
                    if @current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type == 'pause'
                        @current_status = "Active (pause starting #{@current_customer.stop_queues.order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")} until #{(@current_customer.stop_queues.order(created_at: :desc).limit(1).take.end_date-1).strftime("%A %B %d, %Y")})"
                    elsif @current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type == 'cancel'
                        @current_status = "Active (cancel starting #{@current_customer.stop_queues.order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")})"
                    end
                else
                    @current_status = "Active"
                end
                # if @current_customer.pause_cancel_request == 'pause'
                #     @current_status = "Active (pause starting #{(Date.commercial(Date.today.to_date.year, 1+Date.today.to_date.cweek, 1)+7.days).strftime("%B %d, %Y")})"
                # elsif @current_customer.pause_cancel_request == 'cancel'
                #     @current_status = "Active (cancel starting #{(Date.commercial(Date.today.to_date.year, 1+Date.today.to_date.cweek, 1)+7.days).strftime("%B %d, %Y")})"
                # else
                #     @current_status = "Active"
                # end
            else
                if @current_customer.stop_queues.length > 0
                    if @current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type == 'restart'
                        @current_status = "Paused (restarting #{@current_customer.stop_queues.order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")})"
                    end
                else
                    @pause_end = @current_customer.next_pick_up_date.to_date
                    @current_status = "Paused (restarting on #{@pause_end.strftime("%A %B %d, %Y")})"
                end   
                
                
            end
        else
            if @current_customer.stop_queues.length > 0
                if @current_customer.stop_queues.order(created_at: :desc).limit(1).take.stop_type == 'restart'
                    @current_status = "Inactive (restarting #{@current_customer.stop_queues.order(created_at: :desc).limit(1).take.start_date.strftime("%A %B %d, %Y")})"
                end
            else
                @current_status = "Inactive"
            end   
        end

        @number_of_failed_invoices = @current_customer.failed_invoices.where(paid:false).length
        if @number_of_failed_invoices > 0
            @failed_weeks = []
            @current_customer.failed_invoices.where(paid:false).each do |failed_invoice|
                @failed_weeks.push(Chowdy::Application.closest_date(-1,1,failed_invoice.invoice_date).strftime("%B %d"))
            end
        end

        stripe_customer = Stripe::Customer.retrieve(@current_customer.stripe_customer_id)
        card = stripe_customer.sources.all(:object => "card")
        @card_brand = card.data[0].brand
        @card_last4 = card.data[0].last4
        
        unless stripe_customer.subscriptions.data[0].blank?
            current_period_end = stripe_customer.subscriptions.data[0].current_period_end
            @next_billing_date = Time.at(current_period_end).to_datetime + 2.hours
        end
        if @current_customer.recurring_delivery?.blank?
            @delivery_note = "Delivery not requested"
            @delivery_button = "Request delivery"
        else 
            @delivery_note = "Delivery requested"
            @delivery_button = "Update delivery information"
        end
        
        @delivery_address = @current_customer.delivery_address
        @phone_number = @current_customer.phone_number
        @note = @current_customer.special_delivery_instructions

    end

    private

    def user_params
        params.require(:user).permit(:email,:password,:password_confirmation, :stripe_customer_id)
    end

    def require_login
        redirect_to login_path if !logged_in?
    end

end
