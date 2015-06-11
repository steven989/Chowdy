class CustomersController < ApplicationController

protect_from_forgery :except => :create
protect_from_forgery :except => :fail
protect_from_forgery :except => :payment

    def create #create customer account through Stripe webhook

        customer_id = params[:data][:object][:id]
        green_number = params[:data][:object][:metadata][:green_meals_number] 
        customer_email = params[:data][:object][:email].downcase
        customer_name = params[:data][:object][:metadata][:name]
        hub = params[:data][:object][:metadata][:hub].gsub(/\\/,"")
        referral = params[:data][:object][:metadata][:referral]
        
        subscription_id = params[:data][:object][:subscriptions][:data][0][:id]
        plan = params[:data][:object][:subscriptions][:data][0][:plan][:id]

        Customer.delay.create_from_sign_up(customer_id,green_number,customer_email,customer_name,hub,referral,subscription_id,plan)

        render nothing:true, status:200, content_type:'text/html'

    end

    def create_profile
        customer = Customer.where(stripe_customer_id:params[:id]).take
        if customer
            if customer.user
                @user_exists = true
            else
                @user = User.new
                @stripe_customer_id = params[:id]
                @email = customer.email
            end
        else
            @customer_not_found = true
        end
    end

    # def stripe_update #change customer account information through Stripe webhook
    #     #meal count (use customer.subscription.updated hook)
    #     #pause (use customer.subscription.updated hook)
    #     #active/inactive (use customer.subscription.deleted hook)
    # end

    def update #change customer account information from website

        current_customer = current_user.customer
        
        if params[:id].downcase == "pause"
            
            end_date = params[:pause_date_picker]
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            unless end_date.blank?
                adjusted_pause_end_date = Chowdy::Application.closest_date(1,1,end_date) #closest Monday to the requested day
                if [2,3,4].include? Date.today.wday
                    adjusted_pause_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
                else
                    adjusted_pause_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
                end
                if (adjusted_pause_end_date > adjusted_pause_start_date) && (["Yes","yes"].include? current_customer.active?) && !(["Yes","yes"].include? current_customer.paused?)
                    current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                    current_customer.stop_queues.create(stop_type:'pause',associated_cutoff:associated_cutoff, end_date:adjusted_pause_end_date, start_date:adjusted_pause_start_date)
                end
            end

            redirect_to user_profile_path+"#changePlan"

        elsif params[:id].downcase == "cancel"    
            if [2,3,4].include? Date.today.wday
                adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_cancel_start_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            if ["Yes","yes"].include? current_customer.active?
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
                current_customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:params[:cancel_reason])
            else
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").destroy_all
            end
            
            unless params[:feedback].blank?        
                current_customer.feedbacks.create(feedback:params[:feedback], occasion:"cancel") 
            end
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "restart"
            if [2,3,4].include? Date.today.wday
                adjusted_restart_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_restart_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
            
            if current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.blank?
                if ((["Yes","yes"].include? current_customer.active?) && (["Yes","yes"].include? current_customer.paused?)) || (current_customer.active?.blank? || (["No","no"].include? current_customer.active?))
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
                end
            elsif ["pause","cancel"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ?", "pause", "cancel").destroy_all
            elsif ["restart"].include? current_customer.stop_queues.where("stop_type ilike ? or stop_type ilike ? or stop_type ilike ?", "pause", "cancel", "restart").order(created_at: :desc).limit(1).take.stop_type
                    current_customer.stop_queues.where("stop_type ilike ?", "restart").destroy_all
                    current_customer.stop_queues.create(stop_type:'restart',associated_cutoff:associated_cutoff,start_date:adjusted_restart_date)
            end
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "change_card"
            begin
                current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)
                current_stripe_customer.source = params[:stripeToken]
                current_stripe_customer.save
                #attempt to pay back overdue invoices
                if current_customer.failed_invoices.where(paid:false).length > 0 
                    current_customer.failed_invoices.where(paid:false).each do |failed_invoice| 
                        begin 
                            Stripe::Invoice.retrieve(failed_invoice.invoice_number).pay
                        rescue
                            puts "Card declined"
                        else
                            failed_invoice.update_attributes(paid:true,date_paid:Date.today)
                        end
                    end
                end
                notice_status = "success"
                notice_message = "Credit card updated"
            rescue => error
                puts '---------------------------------------------------'
                puts "some error occured when customer tried to update credit card"
                puts error.message
                puts '---------------------------------------------------'
                notice_status = "fail"
                notice_message = "Credit card could not be updated. #{error.message}"
            end
            flash[:status] = notice_status
            flash[:notice_customer_setting] = notice_message
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "email" 
            _old_email = current_customer.email
            unless params[:email].blank?
                begin
                    current_stripe_customer = Stripe::Customer.retrieve(current_customer.stripe_customer_id)   
                    current_stripe_customer.email = params[:email].downcase
                    if current_stripe_customer.save
                        current_customer.update_attributes(email:params[:email].downcase)
                        current_customer.user.update_attributes(email:params[:email].downcase)
                        if current_customer.errors.any? || current_customer.user.errors.any?
                            current_stripe_customer.email = _old_email
                            current_stripe_customer.save
                            current_customer.update(email:_old_email)
                            current_customer.user.update(email:_old_email)
                            notice_message = "Email could not be updated. #{current_customer.errors.full_messages.join(", ")} #{current_customer.user.errors.full_messages.join(", ")}"
                            notice_status = "fail"    
                        else 
                            notice_message = "Email updated"
                            notice_status = "success"                            
                        end
                    end
                rescue => error
                    puts '---------------------------------------------------'
                    puts "some Stripe error occured when customer tried to change email"
                    puts error.message
                    puts '---------------------------------------------------'
                    CustomerMailer.delay.rescued_error(current_customer,"Some Stripe error occured when customer tried to change email: "+error.message.inspect)
                    notice_message = "Email could not be updated. #{error.message}"
                    notice_status = "fail"
                end
                flash[:status] = notice_status
                flash[:notice_customer_setting] = notice_message
                redirect_to user_profile_path+"#settings"
            end
        elsif params[:id].downcase == "hub" 
            if [2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday

            current_customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all
            current_customer.stop_queues.create(
                stop_type:'change_hub',
                associated_cutoff:associated_cutoff,
                start_date:adjusted_change_date,
                cancel_reason: params[:hub] #just using this field to capture any text value
            )
            redirect_to user_profile_path+"#changePlan"
        elsif params[:id].downcase == "delivery" 
            _current_delivery = (["Yes","yes"].include? current_customer.recurring_delivery) ? true : false
            current_customer.update(phone_number:params[:phone_number], delivery_address:params[:delivery_address], special_delivery_instructions:params[:note], recurring_delivery:"yes")
            current_customer.update_attributes(monday_delivery_hub: "delivery") if current_customer.monday_delivery_hub.blank?
            current_customer.update_attributes(thursday_delivery_hub: "delivery") if current_customer.thursday_delivery_hub.blank?
            current_customer.stop_queues.where("stop_type ilike ?", "change_hub").destroy_all
            
            if _current_delivery
                CustomerMailer.delay.stop_delivery_notice(current_customer, "Change delivery info")
            else
                CustomerMailer.delay.stop_delivery_notice(current_customer, "Start Delivery")
            end
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "stop_delivery" 
            current_customer.update(recurring_delivery:nil)
            CustomerMailer.delay.stop_delivery_notice(current_customer, "Stop Delivery")
            redirect_to user_profile_path+"#delivery"
        elsif params[:id].downcase == "name" 
            current_customer.update_attributes(name:params[:name])

            if current_customer.errors.any?
                notice_status = "fail"
                notice_message = "Name could not be updated #{current_customers.errors.full_messages.join(", ")}"
            else
                notice_status = "success"
                notice_message = "Name updated"
            end

            flash[:status] = notice_status
            flash[:notice_customer_setting] = notice_message
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "feedback"
            current_customer.feedbacks.create(feedback:params[:feedback], occasion: 'regular') 
            flash[:status] = "success"
            flash[:notice_customer_setting] = "Feedback received. We appreciate it!"
            redirect_to user_profile_path+"#settings"
        elsif params[:id].downcase == "change_subscription"
            total_updated_meals = params[:monday_reg_hidden].to_i + params[:monday_grn_hidden].to_i + params[:thursday_reg_hidden].to_i + params[:thursday_grn_hidden].to_i
            if [2,3,4].include? Date.today.wday
                adjusted_change_date = Chowdy::Application.closest_date(1,1) #upcoming Monday
            else
                adjusted_change_date = Chowdy::Application.closest_date(2,1) #Two Mondays from now
            end
            associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday

            if ([6,8,10,12,14].include?(total_updated_meals)) && (params[:thursday_grn_hidden].to_i + params[:monday_grn_hidden].to_i <= total_updated_meals)
                current_customer.stop_queues.where("stop_type ilike ?", "change_sub").destroy_all
                current_customer.stop_queues.create(
                    stop_type:'change_sub',
                    associated_cutoff:associated_cutoff,
                    updated_reg_mon:params[:monday_reg_hidden].to_i, 
                    updated_reg_thu:params[:thursday_reg_hidden].to_i, 
                    updated_grn_mon: params[:monday_grn_hidden].to_i, 
                    updated_grn_thu:params[:thursday_grn_hidden].to_i,
                    updated_meals:total_updated_meals, 
                    start_date:adjusted_change_date
                )
            end

            #meal preferences

            no_beef = params[:no_beef].blank? ? false : true
            no_pork = params[:no_pork].blank? ? false : true
            no_poultry = params[:no_poultry].blank? ? false : true
            send_notification = (no_beef != current_customer.no_beef) || (no_pork != current_customer.no_pork) || (no_poultry != current_customer.no_poultry)
            current_customer.update_attributes(no_beef:no_beef,no_pork:no_pork,no_poultry:no_poultry)
            if (["Yes","yes"].include? current_customer.recurring_delivery) && (send_notification)
                CustomerMailer.delay.stop_delivery_notice(current_customer, "Meal preference has changed")
            end

            redirect_to user_profile_path+"#changePlan"
        end

        #affect stripe
            #meal count (change plan in Stripe)      
            #email (change in Stripe)
            #credit card
            #pause (change trial date)
            #active/inactive (add/delete subscriptions; new subscriptions to have trial end date associated with it)
        #all database fields
            #hub (Monday vs. Thursday)
            #name
            #meal split between Monday, Thursdan, regular, green; regular preference
            #delivery

    end

    def customer_sheet
        #create customer sheets 
    end

    def fail #failed charges
        Customer.delay.handle_failed_payment(params[:data][:object][:customer],params[:data][:object][:id],params[:data][:object][:attempt_count].to_i,Time.at(params[:data][:object][:next_payment_attempt]).to_date,params[:data][:object][:lines][:data][0][:amount].to_i,Date.today,Time.at(params[:data][:object][:date]).to_date)
        # stripe_customer_id = params[:data][:object][:customer]
        # invoice_number = params[:data][:object][:id]
        # attempts = params[:data][:object][:attempt_count].to_i
        # next_attempt = Time.at(params[:data][:object][:next_payment_attempt]).to_date
        # invoice_amount = params[:data][:object][:lines][:data][0][:amount].to_i
        # latest_attempt_date = Date.today
        # invoice_date = Time.at(params[:data][:object][:date]).to_date

        # existing_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take

        # if existing_invoice.blank?
        #     if FailedInvoice.create(invoice_number: invoice_number, invoice_date:invoice_date, number_of_attempts:attempts, latest_attempt_date:latest_attempt_date, next_attempt:next_attempt, stripe_customer_id: stripe_customer_id, invoice_amount: invoice_amount)
        #         CustomerMailer.failed_invoice(FailedInvoice.where(invoice_number: invoice_number).take).deliver
        #     end
        # else 
        #     existing_invoice.update_attributes(
        #         number_of_attempts:attempts, 
        #         latest_attempt_date:latest_attempt_date, 
        #         next_attempt:next_attempt, 
        #         invoice_amount: invoice_amount
        #         )
        # end

        render nothing:true, status:200, content_type:'text/html'
    end

    def payment
        Customer.delay.handle_payments(params[:data][:object][:id])
        # if params[:data][:object][:attempt_count].to_i > 1
        #     invoice_number = params[:data][:object][:id]
        #     failed_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take
        #     failed_invoice.update_attributes(paid:true,date_paid:Date.today) unless failed_invoice.blank?
        # end
        render nothing:true, status:200, content_type:'text/html'
    end


    def resend_sign_up_link_form
        @customer = Customer.where(id:params[:id]).take
        respond_to do |format|
          format.html {
            render partial: 'resend_sign_up_link_form'
          }
        end  
    end

    def resend_sign_up_link
        customer = Customer.where(id:params[:id]).take
        target_email = params[:target_email].blank? ? customer.email : params[:target_email]
        CustomerMailer.delay.resend_profile_link(target_email,customer)
        redirect_to user_profile_path+"#customers"
    end

    def resend_sign_up_link_customer_request
        email = params[:email].downcase
        customer = Customer.where(email:email).take
        target_email = params[:target_email].blank? ? customer.email : params[:target_email]
        CustomerMailer.delay.resend_profile_link(target_email,customer)
        
        flash[:status] = "success"
        flash[:login_error] = "We just emailed you the link to create your profile. If you don't get it shortly please email us at <a href='mailto:help@chowdy.ca?subject=Please%20email%20my%20sign%20up%20link%3A%20#{customer.stripe_customer_id}'>help@chowdy.ca</a>"
        redirect_to login_path
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

    def admin
    end

end
