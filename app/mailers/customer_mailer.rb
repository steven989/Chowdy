class CustomerMailer < ActionMailer::Base

  default from: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value

  def confirmation_email(customer,hub,name,start_date,customer_email,meal_count,monday_regular,thursday_regular,monday_green,thursday_green,referral)
    
    @current_customer = customer
    @total_monday = monday_regular.to_i + monday_green.to_i
    @total_thursday = thursday_regular.to_i + thursday_green.to_i
    @green_monday = monday_green
    @green_thursday = thursday_green
    @stripe_customer_id = customer.stripe_customer_id

    @referral = referral

    @hub = hub
    @delivery = !@hub.match(/delivery/i).nil?
    @op_hours = case 
                    when !@hub.match(/wanda/i).nil?
                        "Monday - Saturday, 10:30am to Midnight"
                    when !@hub.match(/dekefir/i).nil?
                        "Monday - Friday, 7:00am to 6:00pm (closed on weekends and holidays)"
                    when !@hub.match(/coffee/i).nil? 
                        "Monday - Saturday, 7:00am to 8:00pm (open 9am on Saturday)"
                end
    @proper_hub_name = case 
                    when !@hub.match(/wanda/i).nil?
                        "Wanda's Belgium Waffle"
                    when !@hub.match(/dekefir/i).nil?
                        "deKEFIR"
                    when !@hub.match(/coffee/i).nil? 
                        "Coffee Bar Inc."
                end
    @hub_address = case 
                    when !@hub.match(/wanda/i).nil?
                        "599 Younge Street"
                    when !@hub.match(/dekefir/i).nil?
                        "333 Bay Street (PATH level beneath Bay Adelaide Centre)"
                    when !@hub.match(/coffee/i).nil? 
                        "346 Front Street West"
                end
    @name = name
    @start_date = start_date
    @meal_count = meal_count

    mail(
      to: customer_email, 
      subject: 'Your Chowdy subscription is confirmed'
      ) do |format|
        format.html
    end
  end

  def duplicate_signup_email(first_name_email,customer_email)
    @name = first_name_email

    mail(
      to: customer_email, 
      subject: 'Duplicate payment refunded'
      ) do |format|
        format.text
    end

  end

  def manual_check_for_signup(customer,manual_checks)
    @customer = customer
    @manual_checks = manual_checks
    mail(
      to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value, 
      subject: 'Customer sign up to look into'
      ) do |format|
        format.text
    end
  end

  def feedback_received(customer)
    @customer = customer
    @feedback = customer.feedbacks.last.feedback
    mail(
      to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value,
      subject: 'New customer feedback'
      ) do |format|
        format.text
    end    
  end

  def stop_delivery_notice(customer,type)
    @customer = customer
    @type = type
    mail(
      to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value,
      subject: 'Change delivery request received'
      ) do |format|
        format.text
    end    
  end

  def failed_invoice(invoice)
    @name = invoice.customer.name.split(/\s/)[0].capitalize

    mail(
      to: invoice.customer.email, 
      subject: 'Credit card declined'
      ) do |format|
        format.text
    end  
  end

  def reset_password_email(user)
    @user = User.find user.id
    @url  = edit_password_reset_url(@user.reset_password_token)
    mail(:to => user.customer.email,
         :subject => "Reset your password")
  end

  def failed_invoice_email
    @all_failed_invoices = FailedInvoice.where(paid:true)
    mail(:to => SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value,
         :subject => "Customers with unpaid invoices")
  end


end
