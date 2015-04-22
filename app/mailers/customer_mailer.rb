class CustomerMailer < ActionMailer::Base
  default from: "steven989@gmail.com"

  def confirmation_email(hub,name,start_date,customer_email,meal_count)
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

end
