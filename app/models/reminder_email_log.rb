class ReminderEmailLog < ActiveRecord::Base
    belongs_to :customer, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id

    def self.generate_customer_list(duration)
        Customer.find_by_sql([
            "

            Select 
                *
            From customers a
            Right Join 

                    (
                    Select
                        a.id as customer_id,
                        max(b.created_at) as latest_cancel_request_created_at,
                        max(c.created_at) as latest_reminder_email_sent

                    From customers a
                    Left Join stop_requests b on a.stripe_customer_id = b.stripe_customer_id and b.request_type ilike '%cancel%' and b.cancel_reason ilike '%taking%break%'
                    Left Join reminder_email_logs c on a.stripe_customer_id = c.stripe_customer_id
                    Left Join no_email_customers d on a.stripe_customer_id = d.stripe_customer_id
                    Where (d.stripe_customer_id is NULL)
                    Group by a.id
                    ) b on a.id = b.customer_id
            Where 
                (b.latest_reminder_email_sent is NULL or ((b.latest_reminder_email_sent < b.latest_cancel_request_created_at) AND (b.latest_reminder_email_sent < ( current_date + (-? * interval '1 day'))) ))
                AND b.latest_cancel_request_created_at < ( current_date + (-? * interval '1 day'))",duration, duration]).select {|c| ["No","no","",nil].include? c.active?}
    
    end

    def self.generate_restart_email(customers)
        customers.each do |c|
            discount = c.reminder_email_logs.blank? ? 500 : nil
            c.add_discount_to_stripe(discount,"discount for restarting Chowdy subscription") if discount
            rm = ReminderEmailLog.create(stripe_customer_id:c.stripe_customer_id,date_reminder_sent:Date.today,discount:discount)
            CustomerMailer.delay.restart_reminder(c,rm)
            if c.user
                c.user.log_activity("System: created and sent restart email #{discount ? 'with discount of $'+(discount.to_f/100).round(2).to_s : 'with no discount'}")
            end
        end
    end

end
