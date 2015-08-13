class CustomerMailer < ActionMailer::Base

  default from: "help@chowdy.ca"

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
                        "Monday - Saturday, 7:00am to 7:00pm (open 9am on Saturday)"
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
      subject: "Your Chowdy subscription is confirmed and begins on #{@start_date.strftime('%B %d')}"
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

  def urgent_stop_delivery_notice(customer,type)
    @customer = customer
    @type = type
    mail(
      to: "steven989@gmail.com",
      subject: 'Change delivery request received'
      ) do |format|
        format.text
    end    
  end

  def anomaly_report(anomalies)
    @anomalies = anomalies
    mail(:to => SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value,
         :subject => "Look into these customers with anomalies")
  end

  def failed_invoice(invoice)
    @customer = invoice.customer
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
    @all_failed_invoices = FailedInvoice.where(paid:false)
    mail(:to => SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value,
         :subject => "Customers with unpaid invoices")
  end

  def scheduled_task_report(report)
    @report = report
    mail(
      to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value, 
      subject: 'Scheduled task report'
      ) do |format|
        format.text
    end 
  end


  def resend_profile_link(target_email,customer)
    @customer = customer
    mail(
      to: target_email, 
      subject: 'Your link to create online profile'
      ) do |format|
        format.text
    end 
  end

  def rescued_error(customer=nil,message)
    @customer = customer
    @message = message
    mail(
      to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value, 
      subject: 'A rescued error has occurred'
      ) do |format|
        format.text
    end 
  end

  def send_customer_list
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date

        hub_array = ['wandas','coffee_bar','dekefir']
        hub_array.each do |hub|
            @id_iterate = 1
            if hub == 'wandas'
                @location = "Wanda's"
                @location_match ='wanda'
                @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & (((monday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no", nil])) | ((monday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])) | ((thursday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no", nil])) | ((thursday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])))}.order("LOWER(name) asc")            
                
            elsif hub == 'coffee_bar'
                @location = "Coffee Bar"
                @location_match ='coffee'
                @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & (((monday_pickup_hub =~ '%coffee%bar%') & (recurring_delivery >> ["No","no", nil])) | ((monday_delivery_hub =~ '%coffee%bar%') & (recurring_delivery >> ["Yes","yes"])) | ((thursday_pickup_hub =~ '%coffee%bar%') & (recurring_delivery >> ["No","no", nil])) | ((thursday_delivery_hub =~ '%coffee%bar%') & (recurring_delivery >> ["Yes","yes"])))}.order("LOWER(name) asc")
            elsif hub == 'dekefir'
                @location = "deKEFIR"
                @location_match ='dekefir'
                @customers = Customer.where{(active? >> ["Yes","yes"]) & (paused?  >> [nil,"No","no"]) & (next_pick_up_date == current_pick_up_date) & (((monday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no", nil])) | ((monday_delivery_hub =~ '%dekefir%') & (recurring_delivery >> ["Yes","yes"])) | ((thursday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no", nil])) | ((thursday_delivery_hub =~ '%dekefir%') & (recurring_delivery << ["Yes","yes"])))}.order("LOWER(name) asc")
            end

            @data = [] 
            @customers.each do |c|
                @data.push({id: @id_iterate,name:c.name.titlecase,email:c.email,reg_mon: if ((c.monday_pickup_hub.match(/#{@location_match}/i)) && (!["Yes","yes"].include?(c.recurring_delivery))) || ((c.monday_delivery_hub.match(/#{@location_match}/i)) && (["Yes","yes"].include?(c.recurring_delivery)) ); c.regular_meals_on_monday.to_i else 0 end, reg_thu: if ((c.thursday_pickup_hub.match(/#{@location_match}/i)) && (!["Yes","yes"].include?(c.recurring_delivery))) || ((c.thursday_delivery_hub.match(/#{@location_match}/i)) && (["Yes","yes"].include?(c.recurring_delivery))); c.regular_meals_on_thursday.to_i else 0 end,grn_mon: if ((c.monday_pickup_hub.match(/#{@location_match}/i)) && (!["Yes","yes"].include?(c.recurring_delivery))) || ((c.monday_delivery_hub.match(/#{@location_match}/i)) && (["Yes","yes"].include?(c.recurring_delivery))); c.green_meals_on_monday.to_i else 0 end, grn_thu: if ((c.thursday_pickup_hub.match(/#{@location_match}/i)) && (!["Yes","yes"].include?(c.recurring_delivery))) || ((c.thursday_delivery_hub.match(/#{@location_match}/i)) && (["Yes","yes"].include?(c.recurring_delivery))); c.green_meals_on_thursday.to_i else 0 end})
                @id_iterate += 1
            end

            if @data.blank?
                attachments["customer_sheet_#{hub}_#{current_pick_up_date.strftime("%Y_%m_%d")}.csv"] = CSV.generate {|csv| csv << ["id","name","email","reg_mon","reg_thu","grn_mon","grn_thu"]}
            else 
                attachments["customer_sheet_#{hub}_#{current_pick_up_date.strftime("%Y_%m_%d")}.csv"] = CSV.generate {|csv| csv << @data.first.keys; @data.each {|data| csv << data.values}}
            end

        end

        mail(
          to: SystemSetting.where(setting:"admin",setting_attribute:"admin_email").take.setting_value, 
          subject: 'Customer list for this week'
          ) do |format|
            format.text
        end 

  end


end
