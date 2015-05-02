class CustomerMailer < ActionMailer::Base
  default from: "steven989@gmail.com"

  def confirmation_email(customer,hub,name,start_date,customer_email,meal_count,monday_regular,thursday_regular,monday_green,thursday_green,referral)
    
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
                        "Monday - Saturday, 7:00am to 9:00pm (open 9am on Saturday)"
                end
    @name = name
    @start_date = start_date
    @meal_count = meal_count

    mail(
      to: customer_email, 
      subject: 'Chowdy confirmation email'
      ) do |format|
        format.text
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
      to: "steven989@gmail.com", 
      subject: 'Customer sign up to look into'
      ) do |format|
        format.text
    end
  end

  def feedback_received(customer)
    @customer = customer
    @feedback = customer.feedbacks.last.feedback
    mail(
      to: "steven989@gmail.com", 
      subject: 'New customer feedback'
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

end
