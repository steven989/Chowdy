class Customer < ActiveRecord::Base
    require 'aws-sdk'
    include PgSearch
    pg_search_scope :search_by_all, :against => [:name, :email, :referral_code, :matched_referrers_code, :delivery_address, :referral, :phone_number, :hub], :using => { :tsearch => {:prefix => true}}
    pg_search_scope :search_by_name_or_email, :against => [:name, :email], :using => { :tsearch => {:prefix => true}}

    belongs_to :user, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
    has_many :feedbacks, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :menu_ratings, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :stop_requests, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :stop_queues, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id, dependent: :destroy 
    has_many :failed_invoices, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id, dependent: :destroy 
    has_many :refunds, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :promotion_redemptions, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :stop_queue_records, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :meal_selections, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :gifts, through: :gift_redemptions
    has_many :gift_redemptions, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :gift_remains, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :partner_product_sales, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :reminder_email_logs, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_one :no_email_customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id
    has_many :photo_submissions, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

    validates :email, uniqueness: true
    validates :referral_code, uniqueness: true, allow_nil: :true, allow_blank: :true

    def self.create_delivery_csv_file

        @deliveries = Customer.where{(active? >> ["Yes","yes"]) & (paused? >> [nil,"No","no"]) & ((recurring_delivery >> ["Yes","yes"])|((hub =~ "%delivery%") &(monday_pickup_hub == nil)))}

        current_pick_up_date = SystemSetting.where(setting:"system_date",setting_attribute:"pick_up_date").take.setting_value.to_date
        production_day_1 = Chowdy::Application.closest_date(-1,7,current_pick_up_date)
        production_day_2 = Chowdy::Application.closest_date(1,3,current_pick_up_date)

        @data = [] 
        @deliveries.each do |c|
            @data.push({
                customer_id:c.id,
                email:c.email,
                name:c.name,
                address:c.delivery_address,
                unit:c.unit_number,
                phone_number:c.phone_number, 
                reg_mon:"#{[nil,'',0].include?(c.regular_meals_on_monday) ? '' : c.regular_meals_on_monday.to_s()+ ' Reg'}" , 
                grn_mon:"#{[nil,'',0].include?(c.green_meals_on_monday) ? '' : c.green_meals_on_monday.to_s() + ' Grn'}", 
                reg_thu:"#{[nil,'',0].include?(c.regular_meals_on_thursday) ? '' : c.regular_meals_on_thursday.to_s() + ' Reg'}", 
                grn_thu:"#{[nil,'',0].include?(c.green_meals_on_thursday) ? '' : c.green_meals_on_thursday.to_s() + ' Grn'}",
                no_pork:"#{c.no_pork ? 'No Pork' : ''}",
                no_beef:"#{c.no_beef ? 'No Beef' : ''}",
                no_poultry:"#{c.no_poultry ? 'No poultry' : ''}",
                monday_delivery_disabled?:"#{c.monday_delivery_enabled? ? '' : 'No Monday Delivery'}",
                thursday_delivery_disabled?:"#{c.thursday_delivery_enabled? ? '' : 'No Thursday Delivery'}",
                extra_ice:"#{c.extra_ice ? 'Extra ice' : ''}",
                gifter_pays_delivery: c.gift_remains.blank? ? (c.gifts.blank? ? '' : (c.gifts.order(id: :desc).limit(1).take.pay_delivery? && Date.today < (c.first_pick_up_date + 5.days) ? c.gifts.order(id: :desc).limit(1).take.sender_email : '' ) ) : (c.gift_remains.order(id: :desc).limit(1).take.gift.pay_delivery? ? c.gift_remains.order(id: :desc).limit(1).take.gift.sender_email : ''),
                multiple_delivery_address:"#{c.different_delivery_address ? 'Multiple Delivery Address' : ''}",
                split_delivery_with:c.split_delivery_with, 
                corporate_office:c.corporate_office,
                corporate:c.corporate,
                beef_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.beef == 0 || c.meal_selections.where(production_day:production_day_1).take.beef.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.beef} Beef"),
                pork_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.pork == 0 || c.meal_selections.where(production_day:production_day_1).take.pork.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.pork} Pork"),
                poultry_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.poultry == 0 || c.meal_selections.where(production_day:production_day_1).take.poultry.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.poultry} Poultry"),
                salad_bowl_1_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.salad_bowl_1 == 0 || c.meal_selections.where(production_day:production_day_1).take.salad_bowl_1.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.salad_bowl_1} Salad Bowl A"),
                salad_bowl_2_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.salad_bowl_2 == 0 || c.meal_selections.where(production_day:production_day_1).take.salad_bowl_2.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.salad_bowl_2} Salad Bowl B"),
                diet_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.diet == 0 || c.meal_selections.where(production_day:production_day_1).take.diet.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.diet} Diet"),
                chefs_special_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.chefs_special == 0 || c.meal_selections.where(production_day:production_day_1).take.chefs_special.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.chefs_special} Chef's Special"),
                green_1_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.green_1 == 0 || c.meal_selections.where(production_day:production_day_1).take.green_1.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.green_1} Green A"),
                green_2_monday:c.meal_selections.where(production_day:production_day_1).blank? ? "" : ((c.meal_selections.where(production_day:production_day_1).take.green_2 == 0 || c.meal_selections.where(production_day:production_day_1).take.green_2.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_1).take.green_2} Green B"),
                beef_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.beef == 0 || c.meal_selections.where(production_day:production_day_2).take.beef.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.beef} Beef"),
                pork_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.pork == 0 || c.meal_selections.where(production_day:production_day_2).take.pork.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.pork} Pork"),
                poultry_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.poultry == 0 || c.meal_selections.where(production_day:production_day_2).take.poultry.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.poultry} Poultry"),
                salad_bowl_1_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.salad_bowl_1 == 0 || c.meal_selections.where(production_day:production_day_2).take.salad_bowl_1.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.salad_bowl_1} Salad Bowl A"),
                salad_bowl_2_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.salad_bowl_2 == 0 || c.meal_selections.where(production_day:production_day_2).take.salad_bowl_2.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.salad_bowl_2} Salad Bowl B"),
                diet_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.diet == 0 || c.meal_selections.where(production_day:production_day_2).take.diet.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.diet} Diet"),
                chefs_special_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.chefs_special == 0 || c.meal_selections.where(production_day:production_day_2).take.chefs_special.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.chefs_special} Chef's Special"),
                green_1_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.green_1 == 0 || c.meal_selections.where(production_day:production_day_2).take.green_1.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.green_1} Green A"),
                green_2_thursday:c.meal_selections.where(production_day:production_day_2).blank? ? "" : ((c.meal_selections.where(production_day:production_day_2).take.green_2 == 0 || c.meal_selections.where(production_day:production_day_2).take.green_2.blank?) ? "" : "#{c.meal_selections.where(production_day:production_day_2).take.green_2} Green B"),
                mon_check: c.meal_selections.where(production_day:production_day_1).blank? ? 0 : c.regular_meals_on_monday.to_i + c.green_meals_on_monday.to_i - (c.meal_selections.where(production_day:production_day_1).take.beef.to_i + c.meal_selections.where(production_day:production_day_1).take.pork.to_i + c.meal_selections.where(production_day:production_day_1).take.poultry.to_i + c.meal_selections.where(production_day:production_day_1).take.salad_bowl_1.to_i + c.meal_selections.where(production_day:production_day_1).take.salad_bowl_2.to_i + c.meal_selections.where(production_day:production_day_1).take.diet.to_i + c.meal_selections.where(production_day:production_day_1).take.chefs_special.to_i + c.meal_selections.where(production_day:production_day_1).take.green_1.to_i + c.meal_selections.where(production_day:production_day_1).take.green_2.to_i),
                thu_check: c.meal_selections.where(production_day:production_day_2).blank? ? 0 : c.regular_meals_on_thursday.to_i + c.green_meals_on_thursday.to_i - (c.meal_selections.where(production_day:production_day_2).take.beef.to_i + c.meal_selections.where(production_day:production_day_2).take.pork.to_i + c.meal_selections.where(production_day:production_day_2).take.poultry.to_i + c.meal_selections.where(production_day:production_day_2).take.salad_bowl_1.to_i + c.meal_selections.where(production_day:production_day_2).take.salad_bowl_2.to_i + c.meal_selections.where(production_day:production_day_2).take.diet.to_i + c.meal_selections.where(production_day:production_day_2).take.chefs_special.to_i + c.meal_selections.where(production_day:production_day_2).take.green_1.to_i + c.meal_selections.where(production_day:production_day_2).take.green_2.to_i),
                special_delivery_instructions:c.special_delivery_instructions,
                monday_delivery_hub:c.monday_delivery_hub,
                thursday_delivery_hub:c.thursday_delivery_hub,
                delivery_boundary:c.delivery_boundary
                })
        end

        header = @data.first.keys
        file = "deliveries_week_of_#{current_pick_up_date.strftime("%Y_%m_%d")}.csv"
        CSV.open(file, "w") do |csv|
            if @data.blank?
                csv << ["id","email","name","delivery_address","unit_number","phone_number","reg_mon","grn_mon","reg_thu","grn_thu","no_pork","no_beef","no_poultry","monday_delivery_enabled","thursday_delivery_enabled","extra_ice","gifter_pays_delivery","multiple_delivery_address","split_delivery_with","corporate_office","corporate","beef_monday","pork_monday","poultry_monday","salad_bowl_1","salad_bowl_2","diet","chefs_special","green_1_monday","green_2_monday","beef_thursday","pork_thursday","poultry_thursday","green_1_thursday","green_2_thursday","mon_check","thu_check","special_delivery_instructions","monday_delivery_hub","thursday_delivery_hub", "delivery_boundary"]
            else
                csv << header
                @data.each do |d|
                    csv << d.values
                end
            end
        end
        file
    end

    def self.store_S3(file)
    # We create a connection with amazon S3
      Aws.config.update({
          :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
          :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
          :region => ENV['S3_REGION']
          })
        s3 = Aws::S3::Resource.new
        object = s3.bucket(ENV['S3_BUCKET_NAME']).object("delivery_csv\\#{File.basename(file)}")
    # the file is not the content of the file is the route
        object.upload_file(File.basename(file),{acl:'public-read'})
    # save the file and return an url to download it
        object.public_url
    end


    def referral_info
        if referral_code = self.matched_referrers_code
            if referrer = Customer.where(referral_code:referral_code).take
                referrer
            else
                nil
            end
        else
            nil
        end
    end

    def self.create_from_sign_up(customer_id,green_number,customer_email,customer_name,hub,referral,subscription_id,plan)
        if customer_name.blank?
            customer_name = customer_email.split("@")[0].to_s
        end

        begin

            manual_checks = []

            case plan
                when "6mealswk" 
                    meal_per_week = 6
                when "8mealswk"
                    meal_per_week = 8
                when "10mealswk"
                    meal_per_week = 10
                when "12mealsweek"
                    meal_per_week = 12
                when "14mealsweek"
                    meal_per_week = 14
                when "4mealswk_pi" 
                    meal_per_week = 4
                when "6mealswk_pi" 
                    meal_per_week = 6
                when "8mealswk_pi"
                    meal_per_week = 8 
                when "10mealswk_pi" 
                    meal_per_week = 10
                when "12mealswk_pi" 
                    meal_per_week = 12
                when "14mealswk_pi" 
                    meal_per_week = 14
            end

            unless Customer.where(stripe_customer_id:customer_id).length > 0 #this is so that Stripe doens't ceaselessly create new customers 


                customer = Customer.create(
                    stripe_customer_id:customer_id, 
                    raw_green_input:green_number, 
                    email:customer_email, 
                    name:customer_name.gsub(/\s$/,""),
                    hub:hub,
                    referral:referral,
                    total_meals_per_week: meal_per_week,
                    stripe_subscription_id: subscription_id,
                    active?:"Yes",
                    first_pick_up_date: StartDate.first.start_date,
                    purchase:"Recurring",
                    next_pick_up_date: StartDate.first.start_date,
                    date_signed_up_for_recurring: Time.now,
                    price_increase_2015:true,
                    corporate:false,
                    monday_delivery_enabled:true,
                    thursday_delivery_enabled:true
                    )

                customer.create_referral_code

                #corporate customer?
                corporate = ["Quickplay","League"].any? {|loc| hub.gsub(/\\/,"").downcase.include?(loc.downcase)}

                if corporate
                    matched_corporate_office = ["Quickplay","League"].select {|loc| hub.gsub(/\\/,"").downcase.include?(loc.downcase)}[0]
                    matched_corporate_office_address = case 
                                                            when !matched_corporate_office.match(/quickplay/i).nil?
                                                                "901 King St West, Toronto, Ontario M5V 3H5"
                                                            when !matched_corporate_office.match(/league/i).nil?
                                                                "101 College St."
                                                        end
                    matched_corporate_office_unit = case 
                                                            when !matched_corporate_office.match(/quickplay/i).nil?
                                                                "Suite 200"
                                                            when !matched_corporate_office.match(/league/i).nil?
                                                                "West Tower, Suite 480"
                                                        end
                    customer.update_attributes(
                        corporate:true,
                        corporate_office:matched_corporate_office,
                        split_delivery_with:matched_corporate_office,
                        delivery_address:matched_corporate_office_address,
                        unit_number:matched_corporate_office_unit,
                        recurring_delivery:"Yes"
                    )
                
                end

                #assign hubs 
                if ((hub.match(/delivery/i).nil?) && (!corporate))
                    customer.update_attributes(monday_pickup_hub:hub,thursday_pickup_hub:hub)
                end


                #add logic to split odd grean meal numbers
                raw_green_input = customer.raw_green_input
                begin
                    Integer(raw_green_input)
                rescue
                    if raw_green_input.nil? || raw_green_input == "null" || raw_green_input.blank?
                            monday_green = 0
                            thursday_green = 0
                    else
                        if raw_green_input.scan(/^all|\ball/i).length == 1 #if the string contains the text "all" at either the beginning of string or preceded by a white space
                            customer.update(number_of_green:meal_per_week)
                            customer.update(green_meals_on_monday:meal_per_week/2)
                            customer.update(green_meals_on_thursday:meal_per_week/2)
                            monday_green = meal_per_week/2
                            thursday_green = meal_per_week/2
                        elsif raw_green_input.scan(/^none|\bnone/i).length == 1 #if the string contains the text "none" at either the beginning of string or preceded by a white space
                            customer.update(number_of_green:0)
                            monday_green = 0
                            thursday_green = 0
                        elsif raw_green_input.scan(/\d+/).length == 1 #if the string contains one number
                            customer.update(number_of_green:raw_green_input.scan(/\d+/)[0].to_i)
                            green_number_to_use = [raw_green_input.scan(/\d+/)[0].to_i,meal_per_week].min
                            if green_number_to_use.odd?
                                if customer.id.odd? #this is to alternate whether Monday or Thursday gets more green
                                    customer.update(green_meals_on_monday:green_number_to_use/2+1)
                                    customer.update(green_meals_on_thursday:green_number_to_use/2)
                                    monday_green = green_number_to_use/2+1
                                    thursday_green = green_number_to_use/2
                                else
                                    customer.update(green_meals_on_thursday:green_number_to_use/2+1)
                                    customer.update(green_meals_on_monday:green_number_to_use/2)
                                    thursday_green = green_number_to_use/2+1
                                    monday_green = green_number_to_use/2
                                end
                            else
                                customer.update(green_meals_on_monday:green_number_to_use/2)
                                customer.update(green_meals_on_thursday:green_number_to_use/2)                    
                                monday_green = green_number_to_use/2
                                thursday_green = green_number_to_use/2
                            end  
                        else 
                            manual_checks.push("Check green meal input")
                            #send email for manual check
                            monday_green = 0
                            thursday_green = 0
                        end
                    end
                else 
                    green_number_to_use = [raw_green_input.to_i,meal_per_week].min
                    customer.update(number_of_green:green_number_to_use)
                        if green_number_to_use.odd?
                            customer.update(green_meals_on_monday:green_number_to_use/2+1)
                            customer.update(green_meals_on_thursday:green_number_to_use/2)
                            monday_green = green_number_to_use/2+1
                            thursday_green = green_number_to_use/2
                        else
                            customer.update(green_meals_on_monday:green_number_to_use/2)
                            customer.update(green_meals_on_thursday:green_number_to_use/2)                    
                            monday_green = green_number_to_use/2
                            thursday_green = green_number_to_use/2
                        end
                end

                #logic to split meal count into Mondays and Thursdays
                    if meal_per_week.odd?
                        customer.update(regular_meals_on_monday:meal_per_week/2+1-monday_green.to_i)
                        customer.update(regular_meals_on_thursday:meal_per_week/2-thursday_green.to_i)
                    else 
                        customer.update(regular_meals_on_monday:meal_per_week/2-monday_green.to_i)
                        customer.update(regular_meals_on_thursday:meal_per_week/2-thursday_green.to_i)
                    end

                #determine gender https://gender-api.com/
                #auto generate a unique customer ID (that's not a sequential number-based ID)
                #add an additional column to track Monday vs. Thursday hubs

                #2) system to update the trial end date in stripe using the StartDate model
                
                begin
                    stripe_customer = Stripe::Customer.retrieve(customer_id)
                    stripe_subscription = stripe_customer.subscriptions.retrieve(subscription_id)
                    stripe_subscription.trial_end = (StartDate.first.start_date+7.days+(23.9).hours).to_time.to_i
                    stripe_subscription.prorate = false
                    stripe_subscription.save
                rescue => error
                    puts '---------------------------------------------------'
                    puts "something went wrong trying to update Stripe subscription after customer is created"
                    puts error.message
                    puts '---------------------------------------------------' 
                    CustomerMailer.rescued_error(customer,"something went wrong trying to update Stripe subscription after customer is created: "+error.message.inspect).deliver
                end

                #3) check for referral and try to match up referrals
                
                unless referral.blank?

                    if Customer.where(referral_code: referral.gsub(" ","").downcase).length == 1 #match code
                        referral_match = Customer.where(referral_code: referral.gsub(" ","").downcase)
                        
                        if referral_match.take.stripe_subscription_id.blank?
                            begin
                                Stripe::InvoiceItem.create(
                                    customer: referral_match.take.stripe_customer_id,
                                    amount: -1000,
                                    currency: 'CAD',
                                    description: "referral bonus"
                                )
                            rescue => error
                                puts '---------------------------------------------------'
                                puts 'Something went wrong while creating Stripe referral bonus invoice item'
                                puts error.message
                                puts '---------------------------------------------------'
                                CustomerMailer.rescued_error(customer,'Something went wrong while creating Stripe referral bonus invoice item: '+error.message.inspect).deliver
                            end
                        else
                            #referrer discount
                            begin
                                stripe_referral_match = Stripe::Customer.retrieve(referral_match.take.stripe_customer_id)
                                stripe_referral_subscription_match = stripe_referral_match.subscriptions.retrieve(referral_match.take.stripe_subscription_id)
                                
                                    #check for existing coupons
                                    if stripe_referral_subscription_match.discount.nil?
                                        stripe_referral_subscription_match.coupon = "referral bonus"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 2"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 2"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 3"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 3"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 4"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 5"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 5"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 6"
                                    elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 6"
                                        stripe_referral_subscription_match.coupon = "referral bonus x 7"
                                    else
                                        do_not_increment_referral = true
                                        CustomerMailer.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)").deliver
                                    end

                                stripe_referral_subscription_match.prorate = false
                                if stripe_referral_subscription_match.save                
                                    referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10) unless do_not_increment_referral
                                end
                            rescue => error
                                puts '---------------------------------------------------'
                                puts 'Something went wrong while updating Stripe referral code'
                                puts error.message
                                puts '---------------------------------------------------'
                                CustomerMailer.rescued_error(customer,'Something went wrong while updating Stripe referral code: '+error.message.inspect).deliver
                            end
                        end                
                        #referree discount

                        begin
                            stripe_subscription.coupon = "referral bonus"
                            stripe_subscription.prorate = false
                            if stripe_subscription.save
                                customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: customer.referral_bonus_referree.to_i + 10)
                            end
                        rescue => error
                                puts '---------------------------------------------------'
                                puts 'Something went wrong while updating Stripe referral code'
                                puts error.message
                                puts '---------------------------------------------------'
                                CustomerMailer.rescued_error(customer,'Something went wrong while updating Stripe referral code: '+error.message).deliver
                        end
                        referral_matched = true
                    
                    elsif Promotion.where("code ilike ? and active = true", referral.gsub(" ","")).length == 1 #match promo code
                        promotion = Promotion.where("code ilike ? and active = true", referral.gsub(" ","")).take
                            if promotion.immediate_refund
                                begin 
                                    charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                                    charge = Stripe::Charge.retrieve(charge_id)
                                    stripe_refund_response = charge.refunds.create(amount: promotion.amount_in_cents)
                                rescue => error
                                    puts '---------------------------------------------------'
                                    puts "Refund cannot be completed"
                                    puts error.message
                                    puts '---------------------------------------------------'
                                    CustomerMailer.rescued_error(customer,"Refund cannot be completed: "+error.message).deliver
                                else
                                    begin
                                        PromotionRedemption.create(stripe_customer_id:customer.stripe_customer_id,promotion_id:promotion.id)
                                        newly_created_refund = Refund.create(stripe_customer_id: customer.stripe_customer_id, refund_week:StartDate.first.start_date, charge_week:Date.today,charge_id:charge_id, meals_refunded: nil, amount_refunded: promotion.amount_in_cents, refund_reason: "Promo code: #{promotion.code}", stripe_refund_id: stripe_refund_response.id)
                                        newly_created_refund.internal_refund_id = newly_created_refund.id
                                        newly_created_refund.save
                                    rescue => error
                                        puts '---------------------------------------------------'
                                        puts "Refund cannot be recorded"
                                        puts error.message
                                        puts '---------------------------------------------------'
                                        CustomerMailer.rescued_error(customer,"Refund cannot be recorded: "+error.message).deliver
                                    else
                                        puts "no issue"
                                    end
                                end
                            else 
                                stripe_subscription.coupon = promotion.stripe_coupon_id
                                stripe_subscription.prorate = false
                                if stripe_subscription.save
                                    PromotionRedemption.create(stripe_customer_id:customer.stripe_customer_id,promotion_id:promotion.id)
                                end
                            end

                    elsif Gift.check_gift_code(referral.gsub(" ",""))[:result]
                        charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                        charge = Stripe::Charge.retrieve(charge_id)
                        Gift.redeem_gift_code(referral.gsub(" ",""),charge,customer,true)
                    else #match name
                        referral_match = Customer.where("name ilike ? and id <> ?", referral.gsub(/\s$/,"").downcase, customer.id)
                        if referral_match.length == 0
                            manual_checks.push("Referral typed in but no match #{referral.gsub(/\s$/,"").downcase}")
                        elsif referral_match.length == 1
                            unless referral_match.take.stripe_subscription_id.blank?
                                #referrer discount
                                begin
                                    stripe_referral_match = Stripe::Customer.retrieve(referral_match.take.stripe_customer_id)
                                    stripe_referral_subscription_match = stripe_referral_match.subscriptions.retrieve(referral_match.take.stripe_subscription_id)
                                    
                                        #check for existing coupons
                                        if stripe_referral_subscription_match.discount.nil?
                                            stripe_referral_subscription_match.coupon = "referral bonus"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 2"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 2"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 3"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 3"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 4"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 4"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 5"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 5"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 6"
                                        elsif stripe_referral_subscription_match.discount.coupon.id == "referral bonus x 6"
                                            stripe_referral_subscription_match.coupon = "referral bonus x 7"
                                        else
                                            do_not_increment_referral = true
                                            CustomerMailer.rescued_error(referral_match.take,"More referrals accrued than available in system (more than 5 referrals)").deliver
                                        end

                                    stripe_referral_subscription_match.prorate = false
                                    if stripe_referral_subscription_match.save                
                                        referral_match.take.update_attributes(referral_bonus_referrer: referral_match.take.referral_bonus_referrer.to_i + 10)  unless do_not_increment_referral
                                    end
                                rescue => error
                                    CustomerMailer.rescued_error(customer,"Error occurred when applying referral discout on stripe: "+error.message.inspect).deliver
                                end
                            end

                            #referree discount
                            stripe_subscription.coupon = "referral bonus"
                            stripe_subscription.prorate = false
                            if stripe_subscription.save
                                customer.update_attributes(matched_referrers_code:referral_match.take.referral_code,referral:referral.gsub(" ",""),referral_bonus_referree: customer.referral_bonus_referree.to_i + 10)
                            end
                            referral_matched = true
                        elsif referral_match.length > 1
                            manual_checks.push("Referral matched multiple customers")
                        end
                    end
                end

                #4) check for potential duplicate payment; automatically try to refund based on information
                    # -1) check if there has been another customer created within the last two hours, based on
                            #email, #name
                            duplicate_match = Customer.where("email ilike ? and name ilike ? and total_meals_per_week = ? and id <> ? and created_at >= ?", customer_email, customer_name, meal_per_week,customer.id,3.hour.ago)
                            if Customer.where("email ilike ? and (name not ilike ? or total_meals_per_week <> ?) and id <> ?", customer_email, customer_name, meal_per_week,customer.id).length >= 1
                                manual_checks.push("New sign up email matches an existing customer but name or total meal count are different")
                            end
                    # -2) refund payment and delete customer
                            if duplicate_match.length >= 1
                                begin 
                                    charge_id = Stripe::Charge.all(customer:customer_id,limit:1).data[0].id
                                    charge = Stripe::Charge.retrieve(charge_id)
                                    charge.refunds.create 
                                rescue => error
                                    puts '---------------------------------------------------'
                                    puts "Refund cannot be completed"
                                    puts error.message
                                    puts '---------------------------------------------------'
                                    CustomerMailer.rescued_error(customer,"Refund cannot be completed: "+error.message.inspect).deliver
                                else
                                    customer.delete_with_stripe
                                    CustomerMailer.duplicate_signup_email(customer_name.split(/\s/)[0].capitalize,customer_email).deliver
                                end
                            end

                #5) send confirmation email
                    hub_email = hub.gsub(/\\/,"")
                    start_date_email = StartDate.first.start_date
                    first_name_email = customer_name.split(/\s/)[0].capitalize
                    
                    email_monday_regular = customer.regular_meals_on_monday
                    email_thursday_regular = customer.regular_meals_on_thursday
                    email_monday_green = customer.green_meals_on_monday
                    email_thursday_green = customer.green_meals_on_thursday

                    referral_name_email = referral.titlecase if referral_matched

                    unless duplicate_match.length >= 1
                        #check to see if this customer was started before backend was deployed
                        unless Customer.where{ (date_signed_up_for_recurring==nil) | (date_signed_up_for_recurring < "2015-06-12")}.map {|c| c.email}.include? customer_email
                            CustomerMailer.confirmation_email(customer,hub_email,first_name_email,start_date_email,customer_email,meal_per_week,email_monday_regular,email_thursday_regular,email_monday_green,email_thursday_green,referral_name_email,corporate).deliver
                        end
                    end

                #6) Send report with actions required
                    # if !hub.match(/delivery/i).nil?
                    #     manual_checks.push("Delivery required")
                    # end
                    #unmatched referrals (added)
                    #green meal count can't be parsed (added) 
                    #Delivery required --> auto send delivery information request email (added)
                    #email matches an existing customer (added)

                    if manual_checks.length >= 1 && duplicate_match.length < 1
                        CustomerMailer.manual_check_for_signup(customer,manual_checks).deliver
                    end
            end
        rescue => error
            CustomerMailer.rescued_error(customer,"New sign up error for #{customer_email}, #{customer_id}: #{error.message.inspect}").deliver
        else
            puts "Customer created"
        end
        
    end


    def meals_split
        raw_green_input = self.raw_green_input
        begin
            Integer(self.raw_green_input)
        rescue
            if raw_green_input.nil? || raw_green_input == "null" || raw_green_input.blank?
                    monday_green = 0
                    thursday_green = 0
            else
                if raw_green_input.scan(/^all|\ball/i).length == 1 #if the string contains the text "all" at either the beginning of string or preceded by a white space
                    self.update(number_of_green:self.total_meals_per_week)
                    self.update(green_meals_on_monday:self.total_meals_per_week/2)
                    self.update(green_meals_on_thursday:self.total_meals_per_week/2)
                    monday_green = self.total_meals_per_week/2
                    thursday_green = self.total_meals_per_week/2
                elsif raw_green_input.scan(/^none|\bnone/i).length == 1 #if the string contains the text "none" at either the beginning of string or preceded by a white space
                    self.update(number_of_green:0)
                    monday_green = 0
                    thursday_green = 0
                elsif raw_green_input.scan(/\d+/).length == 1 #if the string contains one number
                    self.update(number_of_green:raw_green_input.scan(/\d+/)[0].to_i)
                    green_number_to_use = [raw_green_input.scan(/\d+/)[0].to_i,self.total_meals_per_week].min
                    if green_number_to_use.odd?
                        if self.id.odd? #this is to alternate whether Monday or Thursday gets more green
                            self.update(green_meals_on_monday:green_number_to_use/2+1)
                            self.update(green_meals_on_thursday:green_number_to_use/2)
                            monday_green = green_number_to_use/2+1
                            thursday_green = green_number_to_use/2
                        else
                            self.update(green_meals_on_thursday:green_number_to_use/2+1)
                            self.update(green_meals_on_monday:green_number_to_use/2)
                            thursday_green = green_number_to_use/2+1
                            monday_green = green_number_to_use/2
                        end
                    else
                        self.update(green_meals_on_monday:green_number_to_use/2)
                        self.update(green_meals_on_thursday:green_number_to_use/2)                    
                        monday_green = green_number_to_use/2
                        thursday_green = green_number_to_use/2
                    end  
                else 
                    monday_green = 0
                    thursday_green = 0
                end
            end
        else 
            green_number_to_use = [raw_green_input.to_i,self.total_meals_per_week].min
            self.update(number_of_green:green_number_to_use)
                if green_number_to_use.odd?
                    self.update(green_meals_on_monday:green_number_to_use/2+1)
                    self.update(green_meals_on_thursday:green_number_to_use/2)
                    monday_green = green_number_to_use/2+1
                    thursday_green = green_number_to_use/2
                else
                    self.update(green_meals_on_monday:green_number_to_use/2)
                    self.update(green_meals_on_thursday:green_number_to_use/2)                    
                    monday_green = green_number_to_use/2
                    thursday_green = green_number_to_use/2
                end
        end

        #logic to split meal count into Mondays and Thursdays
            if self.total_meals_per_week.odd?
                self.update(regular_meals_on_monday:self.total_meals_per_week/2+1-monday_green.to_i)
                self.update(regular_meals_on_thursday:self.total_meals_per_week/2-thursday_green.to_i)
            else 
                self.update(regular_meals_on_monday:self.total_meals_per_week/2-monday_green.to_i)
                self.update(regular_meals_on_thursday:self.total_meals_per_week/2-thursday_green.to_i)
            end        
    end

    def add_discount_to_stripe(amount,refund_reason)
        begin
            Stripe::InvoiceItem.create(
                customer: self.stripe_customer_id,
                amount: -amount,
                currency: 'CAD',
                description: refund_reason
            )
        rescue => error
            result = "fail"
            notice = "Error occurred when creating discount invoice item for upcoming invoice: #{error.message}"
        else 
            result = "success"
            notice = "Discount invoice item successfully created"
            if self.user
                self.user.log_activity("Discount of $#{(amount.to_f/100).round(2).to_s} added to Stripe#{' : '+refund_reason unless refund_reason.blank?}")
            end
        end
        {result:result,notice:notice}
    end

    def self.handle_failed_payment(stripe_customer_id,invoice_number,attempts,next_attempt,invoice_amount,latest_attempt_date,invoice_date)
        existing_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take

        if existing_invoice.blank?
            if FailedInvoice.create(invoice_number: invoice_number, invoice_date:invoice_date, number_of_attempts:attempts, latest_attempt_date:latest_attempt_date, next_attempt:next_attempt, stripe_customer_id: stripe_customer_id, invoice_amount: invoice_amount)
                CustomerMailer.failed_invoice(FailedInvoice.where(invoice_number: invoice_number).take).deliver
            end
        else 
            existing_invoice.update_attributes(
                number_of_attempts:attempts, 
                latest_attempt_date:latest_attempt_date, 
                next_attempt:next_attempt, 
                invoice_amount: invoice_amount
                )
        end        
    end

    def self.handle_payments(invoice_number,stripe_customer_id)
        failed_invoice = FailedInvoice.where(invoice_number: invoice_number, paid:false).take
        failed_invoice.update_attributes(paid:true,date_paid:Date.today,closed:nil) unless failed_invoice.blank?
        
        remaining_gift = GiftRemain.where("stripe_customer_id ilike ? and created_at < ?",stripe_customer_id,Date.today.to_datetime).take #ignore any remain gift created today because Stripe sends a payment_succeeeded webhook immediately after customer_create webhook
        unless remaining_gift.blank?
            applicable_price = remaining_gift.customer.price_increase_2015? ? 799 : 699
            if remaining_gift.amount_remaining > 0
                Gift.redeem_gift_code(remaining_gift.gift.gift_code,nil,Customer.where(stripe_customer_id:stripe_customer_id).take,false)
            
                if remaining_gift.amount_remaining < (remaining_gift.customer.total_meals_per_week * applicable_price * 1.13).round
                    customer = Customer.where(stripe_customer_id:stripe_customer_id).take
                    associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                    adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1,associated_cutoff)
                    customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:"Gift card #{remaining_gift.gift.gift_code} fell below subscription amount")
                    if customer.user
                        customer.user.log_activity("System: cancelled customer's subscription due to gift amount below subscription")
                    end
                end
            else
                customer = Customer.where(stripe_customer_id:stripe_customer_id).take
                associated_cutoff = Chowdy::Application.closest_date(1,4) #upcoming Thursday
                adjusted_cancel_start_date = Chowdy::Application.closest_date(1,1,associated_cutoff)
                customer.stop_queues.create(stop_type:'cancel',associated_cutoff:associated_cutoff,start_date:adjusted_cancel_start_date,cancel_reason:"Gift card #{remaining_gift.gift.gift_code} ran out")
                if customer.user
                    customer.user.log_activity("System: cancelled customer's subscription due to gift card running out")
                end
            end
            remaining_gift.destroy
        end
    end


    def delete_with_stripe
        begin 
            customer = Stripe::Customer.retrieve(stripe_customer_id)
        rescue => error
            begin
                self.stop_queues.delete_all if self.stop_queues.length > 0
                self.user.destroy unless self.user.nil?
                self.destroy
            rescue => e2
                puts '---------------------------------------------------'
                puts "Error occured while retrieving customer from Stripe for deletion, and deleting customer locally"
                puts '---------------------------------------------------'
                CustomerMailer.delay.rescued_error(self,"Error occured while retrieving customer from Stripe for deletion, and deleting customer locally: "+error.message+". Local error message: "+e2.message)
                {status:false, message:"Error occured while retrieving customer from Stripe: "+error.message+". Something went wrong trying to delete customer on the local server: "+e2.message}
            else
                CustomerMailer.delay.rescued_error(self,"Error occured while retrieving customer from Stripe for deletion, and deleting customer locally: "+error.message+". Customer is completedly deleted on the local server")
                {status:false, message:"Error occured while retrieving customer from Stripe: "+error.message+". Customer is completed deleted on the local server."}
            end
        else
            begin
                customer.delete
            rescue => error
                puts '---------------------------------------------------'
                puts "Error occured while deleting retrieved customer from Stripe"
                puts '---------------------------------------------------'            
                CustomerMailer.delay.rescued_error(self,"Error occured while deleting the retrieved customer from Stripe: "+error.message+". Local server customer not deleted.")
                {status:false, message:"Error occured while deleting the retrieved customer from Stripe: "+error.message+". Local server customer not deleted."}
            else
                begin
                    self.stop_queues.delete_all if self.stop_queues.length > 0
                    self.user.destroy unless self.user.nil?
                    self.destroy
                rescue => e2
                    puts '---------------------------------------------------'
                    puts "Customer deleted on Stripe but could not be deleted on local server"
                    puts '---------------------------------------------------'
                    CustomerMailer.delay.rescued_error(self,"Customer deleted on Stripe but could not be deleted on local server: "+e2.message)
                    {status:false, message:"Customer deleted on Stripe but could not be deleted on local server: "+e2.message}
                else
                    {status:true, message:"Customer successfully deleted from Stripe and local server"}
                end
            end
        end
    end


    def formatted_request_queues
        iterator = 1
        output_array = []
        self.stop_queues.each do |sq|
            if sq.stop_type == "change_sub"
                if sq.updated_meals.to_i  < sq.customer.total_meals_per_week
                    output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): decrease to #{sq.updated_meals.to_i} meals")
                else
                    output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): increase to #{sq.updated_meals.to_i} meals")
                end
            elsif sq.stop_type == "cancel"
                output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): cancel")
            elsif sq.stop_type == "pause"
                output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): pause until #{sq.end_date}")
            elsif sq.stop_type == "change_hub"
                output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): change hub to #{sq.cancel_reason}")
            elsif sq.stop_type == "restart"
                output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): restart")
            else
                output_array.push("#{iterator} (#{sq.created_at.strftime('%b %d')}): "+sq.stop_type.capitalize)
            end
            iterator += 1
        end
        output_array.join(", ")
    end

    def create_referral_code
        base = self.name.split(/\s/)[0].downcase
        base_last = self.name.split(/\s/)[1][0..3].downcase unless self.name.split(/\s/)[1].nil?
        numerical = Customer.where("name ilike ?", "%#{base}%").length
        code_candidate = base.to_s + base_last.to_s + (numerical*rand(5..10)).to_s
        while Customer.where(referral_code: code_candidate).length > 0 do
            numerical += 11
            code_candidate = base.to_s + numerical.to_s
        end
        self.update_attribute(:referral_code, code_candidate)
    end

    def balance_meals

        total_meals = self.regular_meals_on_monday.to_i + self.regular_meals_on_thursday.to_i + self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        green_meals = self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        regular_meals = total_meals - green_meals

        if total_meals.odd?
            total_meals_1 = total_meals/2+1
            total_meals_2 = total_meals/2
        else
            total_meals_1 = total_meals/2
            total_meals_2 = total_meals/2
        end

        if green_meals.odd?
            green_meals_1 = green_meals/2+1
            green_meals_2 = green_meals/2
        else
            green_meals_1 = green_meals/2
            green_meals_2 = green_meals/2
        end

        regular_meals_1 = total_meals_1 - green_meals_1
        regular_meals_2 = total_meals_2 - green_meals_2

        self.update(regular_meals_on_monday:regular_meals_1,green_meals_on_monday:green_meals_1,regular_meals_on_thursday:regular_meals_2,green_meals_on_thursday:green_meals_2)

    end

    def all_meals_on_day_1
        total_meals = self.regular_meals_on_monday.to_i + self.regular_meals_on_thursday.to_i + self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        green_meals = self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        regular_meals = total_meals - green_meals
        self.update(regular_meals_on_monday:regular_meals,green_meals_on_monday:green_meals,regular_meals_on_thursday:0,green_meals_on_thursday:0)
    end

    def self.send_admin_delivery_csv
        file = Customer.create_delivery_csv_file
        url = Customer.store_S3(file)
        CustomerMailer.send_delivery_csv_to_admin(url).deliver
    end

    def all_meals_on_day_2
        total_meals = self.regular_meals_on_monday.to_i + self.regular_meals_on_thursday.to_i + self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        green_meals = self.green_meals_on_monday.to_i + self.green_meals_on_thursday.to_i
        regular_meals = total_meals - green_meals
        self.update(regular_meals_on_monday:0,green_meals_on_monday:0,regular_meals_on_thursday:regular_meals,green_meals_on_thursday:green_meals)
    end

    def self.meal_count(count_type)
        current_pick_up_date = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
        active_nonpaused_customers = Customer.where(active?: ["Yes","yes"], paused?: [nil,"No","no"], next_pick_up_date:current_pick_up_date)
        production_day_1 = Chowdy::Application.closest_date(-1,7,current_pick_up_date)
        production_day_2 = Chowdy::Application.closest_date(1,3,current_pick_up_date)
        current_week_monday_selected = MealSelection.where(production_day:production_day_1)
        current_week_thursday_selected = MealSelection.where(production_day:production_day_2)
        
        monday_regular = active_nonpaused_customers.sum(:regular_meals_on_monday).to_i
            monday_regular_wandas = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
            monday_regular_red_bench = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%bench%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
            monday_regular_green_grind = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%grind%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
            monday_regular_coffee_bar = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
            monday_regular_dekefir = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:regular_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
            monday_regular_gta_delivery = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%gta%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i
        monday_green = active_nonpaused_customers.sum(:green_meals_on_monday).to_i
            monday_green_wandas = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
            monday_green_red_bench = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%bench%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%bench%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
            monday_green_green_grind = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%grind%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%grind%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
            monday_green_coffee_bar = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
            monday_green_dekefir = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:green_meals_on_monday).to_i + active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
            monday_green_gta_delivery = active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null", "%gta%").where{meal_selections.id == nil}.sum(:green_meals_on_monday).to_i
        thursday_regular = active_nonpaused_customers.sum(:regular_meals_on_thursday).to_i
            thursday_regular_wandas = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
            thursday_regular_red_bench = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%bench%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
            thursday_regular_green_grind = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%grind%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
            thursday_regular_coffee_bar = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
            thursday_regular_dekefir = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:regular_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
            thursday_regular_gta_delivery = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%gta%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i
        thursday_green = active_nonpaused_customers.sum(:green_meals_on_thursday).to_i
            thursday_green_wandas = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%wanda%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%wanda%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
            thursday_green_red_bench = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%bench%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%bench%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
            thursday_green_green_grind = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%grind%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%grind%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
            thursday_green_coffee_bar = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%coffee%bar%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%coffee%bar%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
            thursday_green_dekefir = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null", "%dekefir%").sum(:green_meals_on_thursday).to_i + active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%dekefir%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
            thursday_green_gta_delivery = active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null", "%gta%").where{meal_selections.id == nil}.sum(:green_meals_on_thursday).to_i
        total_meals = monday_regular + monday_green + thursday_regular + thursday_green

        # Pauses taking place next week
        pause_next_week = StopQueue.where(stop_type:"pause").map {|q| q.customer.total_meals_per_week.to_i }.inject {|sum, x| sum + x}.to_i
        cancel_next_week = StopQueue.where(stop_type:"cancel").map {|q| q.customer.total_meals_per_week.to_i }.inject {|sum, x| sum + x}.to_i
        unpause_next_week = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:total_meals_per_week).to_i
        restarts_next_week = StopQueue.where(stop_type:"restart").map {|q| q.customer.total_meals_per_week.to_i }.inject {|sum, x| sum + x}.to_i
        meal_count_change = (StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.sum(:updated_meals).to_i - StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.map {|r| r.customer.total_meals_per_week.to_i}.inject {|sum, x| sum + x}.to_i).to_i
        new_sign_ups = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date) ).sum(:total_meals_per_week).to_i

        total_meals_next = total_meals - pause_next_week - cancel_next_week + unpause_next_week + restarts_next_week + meal_count_change + new_sign_ups 

        if count_type == "total_customer"
            active_nonpaused_customers.length.to_i
        elsif count_type == "total_customer_next_week"
            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            next_week_customers = Customer.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}

            next_week_customers.length.to_i
        elsif count_type == "monday_regular"
            monday_regular
        elsif count_type == "monday_regular_wandas"
            monday_regular_wandas
        elsif count_type == "monday_regular_red_bench"
            monday_regular_red_bench
        elsif count_type == "monday_regular_green_grind"
            monday_regular_green_grind
        elsif count_type == "monday_regular_coffee_bar"
            monday_regular_coffee_bar
        elsif count_type == "monday_regular_dekefir"
            monday_regular_dekefir
        elsif count_type == "monday_regular_gta_delivery"
            monday_regular_gta_delivery
        elsif count_type == "monday_green"
            monday_green
        elsif count_type == "monday_green_wandas"
            monday_green_wandas
        elsif count_type == "monday_green_red_bench"
            monday_green_red_bench
        elsif count_type == "monday_green_green_grind"
            monday_green_green_grind
        elsif count_type == "monday_green_coffee_bar"
            monday_green_coffee_bar
        elsif count_type == "monday_green_dekefir"
            monday_green_dekefir
        elsif count_type == "monday_green_gta_delivery"
            monday_green_gta_delivery
        elsif count_type == "thursday_regular"
            thursday_regular
        elsif count_type == "thursday_regular_wandas"
            thursday_regular_wandas
        elsif count_type == "thursday_regular_red_bench"
            thursday_regular_red_bench
        elsif count_type == "thursday_regular_green_grind"
            thursday_regular_green_grind
        elsif count_type == "thursday_regular_coffee_bar"
            thursday_regular_coffee_bar
        elsif count_type == "thursday_regular_dekefir"
            thursday_regular_dekefir
        elsif count_type == "thursday_regular_gta_delivery"
            thursday_regular_gta_delivery
        elsif count_type == "thursday_green"
            thursday_green
        elsif count_type == "thursday_green_wandas"
            thursday_green_wandas
        elsif count_type == "thursday_green_red_bench"
            thursday_green_red_bench
        elsif count_type == "thursday_green_green_grind"
            thursday_green_green_grind
        elsif count_type == "thursday_green_coffee_bar"
            thursday_green_coffee_bar
        elsif count_type == "thursday_green_dekefir"
            thursday_green_dekefir
        elsif count_type == "thursday_green_gta_delivery"
            thursday_green_gta_delivery
        elsif count_type == "total_meals"
            total_meals
        elsif count_type == "total_meals_next"
            total_meals_next
        elsif count_type == "neg_adjustment_pork_monday_wandas"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_pork_monday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_pork_monday_dekefir"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_pork_monday_red_bench"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_pork_monday_green_grind"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_pork_monday"
            neg_adjustment_pork_monday_wandas = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_pork_monday_coffee_bar = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_pork_monday_dekefir = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_pork_monday_red_bench = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%bench%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%bench%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_pork_monday_green_grind = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%grind%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%grind%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_pork_monday_wandas + neg_adjustment_pork_monday_coffee_bar + neg_adjustment_pork_monday_dekefir + neg_adjustment_pork_monday_red_bench + neg_adjustment_pork_monday_green_grind
        elsif count_type == "neg_adjustment_pork_thursday_wandas"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_pork_thursday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_pork_thursday_dekefir"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_pork_thursday_red_bench"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_pork_thursday_green_grind"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_pork_thursday"
            neg_adjustment_pork_thursday_wandas = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_pork_thursday_coffee_bar = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_pork_thursday_dekefir = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_pork_thursday_red_bench = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_pork_thursday_green_grind = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_pork is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_pork is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_pork_thursday_wandas + neg_adjustment_pork_thursday_coffee_bar + neg_adjustment_pork_thursday_dekefir + neg_adjustment_pork_thursday_red_bench + neg_adjustment_pork_thursday_green_grind
        elsif count_type == "neg_adjustment_beef_monday_wandas"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_beef_monday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_beef_monday_dekefir"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_beef_monday_red_bench"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_beef_monday_green_grind"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_beef_monday"
            neg_adjustment_beef_monday_wandas = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_beef_monday_coffee_bar = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_beef_monday_dekefir = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_beef_monday_red_bench = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%bench%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%bench%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_beef_monday_green_grind = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%grind%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%grind%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_beef_monday_wandas + neg_adjustment_beef_monday_coffee_bar + neg_adjustment_beef_monday_dekefir + neg_adjustment_beef_monday_red_bench + neg_adjustment_beef_monday_green_grind
        elsif count_type == "neg_adjustment_beef_thursday_wandas"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_beef_thursday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_beef_thursday_dekefir"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_beef_thursday_red_bench"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_beef_thursday_green_grind"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_beef_thursday"
            neg_adjustment_beef_thursday_wandas = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_beef_thursday_coffee_bar = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_beef_thursday_dekefir = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_beef_thursday_red_bench = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_beef_thursday_green_grind = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_beef is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_beef is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_beef_thursday_wandas + neg_adjustment_beef_thursday_coffee_bar + neg_adjustment_beef_thursday_dekefir + neg_adjustment_beef_thursday_red_bench + neg_adjustment_beef_thursday_green_grind
        elsif count_type == "neg_adjustment_poultry_monday_wandas"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_monday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_monday_dekefir"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_monday_red_bench"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_monday_green_grind"
            (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_monday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_monday"
            neg_adjustment_poultry_monday_wandas = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%wanda%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_poultry_monday_coffee_bar = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%coffee%bar%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_poultry_monday_dekefir = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%dekefir%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_poultry_monday_red_bench = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%bench%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%bench%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_poultry_monday_green_grind = (active_nonpaused_customers.where("monday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%grind%").sum(:regular_meals_on_monday).to_i/3) + (active_nonpaused_customers.where("monday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%grind%").sum(:regular_meals_on_monday).to_i/3)
            neg_adjustment_poultry_monday_wandas + neg_adjustment_poultry_monday_coffee_bar + neg_adjustment_poultry_monday_dekefir + neg_adjustment_poultry_monday_red_bench + neg_adjustment_poultry_monday_green_grind
        elsif count_type == "neg_adjustment_poultry_thursday_wandas"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%wanda%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_thursday_coffee_bar"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%coffee%bar%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_thursday_dekefir"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%dekefir%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_thursday_red_bench"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%bench%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_thursday_green_grind"
            (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%grind%").where{meal_selections.id == nil}.sum(:regular_meals_on_thursday).to_i/3)
        elsif count_type == "neg_adjustment_poultry_thursday"        
            neg_adjustment_poultry_thursday_wandas = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%wanda%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_poultry_thursday_coffee_bar = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%coffee%bar%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_poultry_thursday_dekefir = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%dekefir%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_poultry_thursday_red_bench = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%bench%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_poultry_thursday_green_grind = (active_nonpaused_customers.where("thursday_pickup_hub ilike ? and recurring_delivery is null and no_poultry is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3) + (active_nonpaused_customers.where("thursday_delivery_hub ilike ? and recurring_delivery is not null and no_poultry is true", "%grind%").sum(:regular_meals_on_thursday).to_i/3)
            neg_adjustment_poultry_thursday_wandas + neg_adjustment_poultry_thursday_coffee_bar + neg_adjustment_poultry_thursday_dekefir + neg_adjustment_poultry_thursday_red_bench + neg_adjustment_poultry_thursday_green_grind
        elsif count_type == "neg_adjustment_poultry_next_monday"        
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_monday_selected = MealSelection.where(production_day:production_day_1)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}.where{meal_selections.id == nil}
            
            preference_negs_master_subset.where(no_poultry:true).sum(:regular_meals_on_monday).to_i/3
        elsif count_type == "neg_adjustment_beef_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_monday_selected = MealSelection.where(production_day:production_day_1)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}.where{meal_selections.id == nil}

            preference_negs_master_subset.where(no_beef:true).sum(:regular_meals_on_monday).to_i/3
        elsif count_type == "neg_adjustment_pork_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_monday_selected = MealSelection.where(production_day:production_day_1)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}.where{meal_selections.id == nil}

            preference_negs_master_subset.where(no_pork:true).sum(:regular_meals_on_monday).to_i/3
        elsif count_type == "neg_adjustment_poultry_next_thursday"        
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_thursday_selected = MealSelection.where(production_day:production_day_2)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}.where{meal_selections.id == nil}

            preference_negs_master_subset.where(no_poultry:true).sum(:regular_meals_on_thursday).to_i/3
        elsif count_type == "neg_adjustment_beef_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_thursday_selected = MealSelection.where(production_day:production_day_2)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}.where{meal_selections.id == nil}

            preference_negs_master_subset.where(no_beef:true).sum(:regular_meals_on_thursday).to_i/3
        elsif count_type == "neg_adjustment_pork_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            next_week_thursday_selected = MealSelection.where(production_day:production_day_2)

            current_customers = active_nonpaused_customers.map {|c| c.stripe_customer_id} #in
            pausing_customers = StopQueue.where(stop_type:"pause").map {|q| q.stripe_customer_id} #not in
            canceling_customers = StopQueue.where(stop_type:"cancel").map {|q| q.stripe_customer_id} #not in
            unpausing_customers = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).map {|c| c.stripe_customer_id} #in
            restarting_customers = StopQueue.where(stop_type:"restart").map {|q| q.stripe_customer_id} #in
            new_customers = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).map {|c| c.stripe_customer_id} #in
            preference_negs_master_subset = Customer.joins{next_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{((stripe_customer_id >> current_customers) & (stripe_customer_id << pausing_customers) & (stripe_customer_id << canceling_customers)) | (stripe_customer_id >> unpausing_customers) | (stripe_customer_id >> restarting_customers) | (stripe_customer_id >> new_customers)}

            preference_negs_master_subset.where(no_pork:true).sum(:regular_meals_on_thursday).to_i/3
        elsif count_type == "regular_meals_next_monday"
            pause_next_monday_regular = StopQueue.where(stop_type:"pause").map {|q| q.customer.regular_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_regular = StopQueue.where(stop_type:"cancel").map {|q| q.customer.regular_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_regular = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:regular_meals_on_monday).to_i
            restarts_next_monday_regular = StopQueue.where(stop_type:"restart").map {|q| q.customer.regular_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_regular = StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i - e.customer.regular_meals_on_monday.to_i}
            new_sign_ups_next_monday_regular = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).sum(:regular_meals_on_monday).to_i
            
            regular_meals_next_monday = monday_regular - pause_next_monday_regular - cancel_next_monday_regular + unpause_next_monday_regular + restarts_next_monday_regular + meal_count_change_next_monday_regular + new_sign_ups_next_monday_regular

        elsif count_type == "regular_meals_next_thursday"
            pause_next_thursday_regular = StopQueue.where(stop_type:"pause").map {|q| q.customer.regular_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_regular = StopQueue.where(stop_type:"cancel").map {|q| q.customer.regular_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_regular = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_regular = StopQueue.where(stop_type:"restart").map {|q| q.customer.regular_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_regular = StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i - e.customer.regular_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_regular = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).sum(:regular_meals_on_thursday).to_i

            regular_meals_next_thursday = thursday_regular - pause_next_thursday_regular - cancel_next_thursday_regular + unpause_next_thursday_regular + restarts_next_thursday_regular + meal_count_change_next_thursday_regular + new_sign_ups_next_thursday_regular
            regular_meals_next_thursday

        elsif count_type == "green_meals_next_monday"
            pause_next_monday_green = StopQueue.where(stop_type:"pause").map {|q| q.customer.green_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_green = StopQueue.where(stop_type:"cancel").map {|q| q.customer.green_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_green = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:green_meals_on_monday).to_i
            restarts_next_monday_green = StopQueue.where(stop_type:"restart").map {|q| q.customer.green_meals_on_monday.to_i }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_green = StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_grn_mon.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_green = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).sum(:green_meals_on_monday).to_i
            
            green_meals_next_monday = monday_green - pause_next_monday_green - cancel_next_monday_green + unpause_next_monday_green + restarts_next_monday_green + meal_count_change_next_monday_green + new_sign_ups_next_monday_green

        elsif count_type == "green_meals_next_thursday"
            pause_next_thursday_green = StopQueue.where(stop_type:"pause").map {|q| q.customer.green_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_green = StopQueue.where(stop_type:"cancel").map {|q| q.customer.green_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_green = Customer.where(paused?: ["Yes","yes"], pause_end_date: [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]).sum(:green_meals_on_thursday).to_i
            restarts_next_thursday_green = StopQueue.where(stop_type:"restart").map {|q| q.customer.green_meals_on_thursday.to_i }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_green = StopQueue.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_grn_thu.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_green = Customer.where(active?:["Yes","yes"], next_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date), first_pick_up_date: Chowdy::Application.closest_date(1,1,current_pick_up_date)).sum(:green_meals_on_thursday).to_i

            green_meals_next_thursday = thursday_green - pause_next_thursday_green - cancel_next_thursday_green + unpause_next_thursday_green + restarts_next_thursday_green + meal_count_change_next_thursday_green + new_sign_ups_next_thursday_green
        elsif count_type == "wandas_meals_next_monday"
            pause_next_monday_wandas = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.monday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_wandas = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.monday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_wandas = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((monday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_monday).to_i
            restarts_next_monday_wandas = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.monday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_wandas = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_wandas = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((monday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_wandas = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%wanda%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%wanda%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i}
        
            wandas_meals_next_monday = monday_regular_wandas + monday_green_wandas - pause_next_monday_wandas - cancel_next_monday_wandas + unpause_next_monday_wandas + restarts_next_monday_wandas + meal_count_change_next_monday_wandas + new_sign_ups_next_monday_wandas + hub_change_next_monday_wandas

        elsif count_type == "wandas_meals_next_thursday"
            pause_next_thursday_wandas = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.thursday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_wandas = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.thursday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_wandas = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((thursday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_wandas = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.thursday_pickup_hub.match(/wanda/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/wanda/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_wandas = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_wandas = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((thursday_pickup_hub =~ '%wanda%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%wanda%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_wandas = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%wanda%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%wanda%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%wanda%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i}

            wandas_meals_next_thursday = thursday_regular_wandas + thursday_green_wandas - pause_next_thursday_wandas - cancel_next_thursday_wandas + unpause_next_thursday_wandas + restarts_next_thursday_wandas + meal_count_change_next_thursday_wandas + new_sign_ups_next_thursday_wandas + hub_change_next_thursday_wandas
        elsif count_type == "coffee_bar_meals_next_monday"
            pause_next_monday_coffee_bar = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.monday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_coffee_bar = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.monday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_coffee_bar = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((monday_pickup_hub =~ '%coffee%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%coffee%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_monday).to_i
            restarts_next_monday_coffee_bar = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.monday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_coffee_bar = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_coffee_bar = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((monday_pickup_hub =~ '%coffee%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%coffee%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_coffee_bar = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%coffee%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%coffee%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i}

            coffee_bar_meals_next_monday = monday_regular_coffee_bar + monday_green_coffee_bar - pause_next_monday_coffee_bar - cancel_next_monday_coffee_bar + unpause_next_monday_coffee_bar + restarts_next_monday_coffee_bar + meal_count_change_next_monday_coffee_bar + new_sign_ups_next_monday_coffee_bar + hub_change_next_monday_coffee_bar

        elsif count_type == "coffee_bar_meals_next_thursday"
            pause_next_thursday_coffee_bar = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.thursday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_coffee_bar = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.thursday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_coffee_bar = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((thursday_pickup_hub =~ '%coffee%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%coffee%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_coffee_bar = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.thursday_pickup_hub.match(/coffee/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/coffee/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_coffee_bar = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_coffee_bar = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((thursday_pickup_hub =~ '%coffee%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%coffee%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_coffee_bar = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%coffee%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%coffee%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%coffee%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%coffee%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i}

            coffee_bar_meals_next_thursday = thursday_regular_coffee_bar + thursday_green_coffee_bar - pause_next_thursday_coffee_bar - cancel_next_thursday_coffee_bar + unpause_next_thursday_coffee_bar + restarts_next_thursday_coffee_bar + meal_count_change_next_thursday_coffee_bar + new_sign_ups_next_thursday_coffee_bar + hub_change_next_thursday_coffee_bar

        elsif count_type == "dekefir_meals_next_monday"
            pause_next_monday_dekefir = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.monday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_dekefir = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.monday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_dekefir = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((monday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%dekefir%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_monday).to_i
            restarts_next_monday_dekefir = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.monday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_dekefir = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_dekefir = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((monday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%dekefir%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_dekefir = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%dekefir%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%dekefir%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i}
        
            dekefir_meals_next_monday = monday_regular_dekefir + monday_green_dekefir - pause_next_monday_dekefir - cancel_next_monday_dekefir + unpause_next_monday_dekefir + restarts_next_monday_dekefir + meal_count_change_next_monday_dekefir + new_sign_ups_next_monday_dekefir + hub_change_next_monday_dekefir



        elsif count_type == "dekefir_meals_next_thursday"
            pause_next_thursday_dekefir = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.thursday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_dekefir = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.thursday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_dekefir = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((thursday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%dekefir%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_dekefir = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.thursday_pickup_hub.match(/dekefir/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/dekefir/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_dekefir = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_dekefir = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((thursday_pickup_hub =~ '%dekefir%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%dekefir%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_dekefir = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%dekefir%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%dekefir%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%dekefir%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i}
   
            dekefir_meals_next_thursday = thursday_regular_dekefir + thursday_green_dekefir - pause_next_thursday_dekefir - cancel_next_thursday_dekefir + unpause_next_thursday_dekefir + restarts_next_thursday_dekefir + meal_count_change_next_thursday_dekefir + new_sign_ups_next_thursday_dekefir + hub_change_next_thursday_dekefir


        elsif count_type == "red_bench_meals_next_monday"
            pause_next_monday_red_bench = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.monday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_red_bench = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.monday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_red_bench = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((monday_pickup_hub =~ '%bench%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%bench%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_monday).to_i
            restarts_next_monday_red_bench = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.monday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_red_bench = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_red_bench = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((monday_pickup_hub =~ '%bench%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%bench%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_red_bench = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%bench%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%bench%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i}
        
            red_bench_meals_next_monday = monday_regular_red_bench + monday_green_red_bench - pause_next_monday_red_bench - cancel_next_monday_red_bench + unpause_next_monday_red_bench + restarts_next_monday_red_bench + meal_count_change_next_monday_red_bench + new_sign_ups_next_monday_red_bench + hub_change_next_monday_red_bench



        elsif count_type == "red_bench_meals_next_thursday"
            pause_next_thursday_red_bench = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.thursday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_red_bench = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.thursday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_red_bench = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((thursday_pickup_hub =~ '%bench%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%bench%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_red_bench = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.thursday_pickup_hub.match(/bench/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/bench/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_red_bench = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_red_bench = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((thursday_pickup_hub =~ '%bench%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%bench%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_red_bench = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%bench%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%bench%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%bench%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%bench%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i}
   
            red_bench_meals_next_thursday = thursday_regular_red_bench + thursday_green_red_bench - pause_next_thursday_red_bench - cancel_next_thursday_red_bench + unpause_next_thursday_red_bench + restarts_next_thursday_red_bench + meal_count_change_next_thursday_red_bench + new_sign_ups_next_thursday_red_bench + hub_change_next_thursday_red_bench

        elsif count_type == "green_grind_meals_next_monday"
            pause_next_monday_green_grind = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.monday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_green_grind = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.monday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_green_grind = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((monday_pickup_hub =~ '%grind%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%grind%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_monday).to_i
            restarts_next_monday_green_grind = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.monday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.monday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_green_grind = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_green_grind = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((monday_pickup_hub =~ '%grind%') & (recurring_delivery >> ["No","no",nil])) | ((monday_delivery_hub =~ '%grind%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_green_grind = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%grind%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%grind%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.monday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.monday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i}
        
            green_grind_meals_next_monday = monday_regular_green_grind + monday_green_green_grind - pause_next_monday_green_grind - cancel_next_monday_green_grind + unpause_next_monday_green_grind + restarts_next_monday_green_grind + meal_count_change_next_monday_green_grind + new_sign_ups_next_monday_green_grind + hub_change_next_monday_green_grind



        elsif count_type == "green_grind_meals_next_thursday"
            pause_next_thursday_green_grind = StopQueue.where(stop_type:"pause").map {|q| if (q.customer.thursday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_green_grind = StopQueue.where(stop_type:"cancel").map {|q| if (q.customer.thursday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_thursday_green_grind = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((thursday_pickup_hub =~ '%grind%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%grind%') & (recurring_delivery >> ["Yes","yes"])))}.sum(:regular_meals_on_thursday).to_i
            restarts_next_thursday_green_grind = StopQueue.where(stop_type:"restart").map {|q| if (q.customer.thursday_pickup_hub.match(/grind/i) && ([nil,"No","no"].include? q.customer.recurring_delivery)) || (q.customer.thursday_delivery_hub.match(/grind/i) && (["Yes","yes"].include? q.customer.recurring_delivery)); q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_green_grind = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_green_grind = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((thursday_pickup_hub =~ '%grind%') & (recurring_delivery >> ["No","no",nil])) | ((thursday_delivery_hub =~ '%grind%') & (recurring_delivery >> ["Yes","yes"])))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_green_grind = StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%grind%") & (stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} + StopQueue.where{(stop_type =~ "change_hub") & (stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (cancel_reason =~ "%grind%") & (stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id})}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.thursday_pickup_hub =~ '%grind%') & (customers.recurring_delivery >> ["No","no",nil])) | ((customers.thursday_delivery_hub =~ '%grind%') & (customers.recurring_delivery >> ["Yes","yes"])))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i}
   
            green_grind_meals_next_thursday = thursday_regular_green_grind + thursday_green_green_grind - pause_next_thursday_green_grind - cancel_next_thursday_green_grind + unpause_next_thursday_green_grind + restarts_next_thursday_green_grind + meal_count_change_next_thursday_green_grind + new_sign_ups_next_thursday_green_grind + hub_change_next_thursday_green_grind


        elsif count_type == "hub_unassigned_meals_next_monday"
            monday_hub_unassigned = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == current_pick_up_date) & (((recurring_delivery >> [nil,"No","no"]) & ((monday_pickup_hub == nil) | ((monday_pickup_hub !~ '%wanda%') & (monday_pickup_hub !~ '%bench%') & (monday_pickup_hub !~ '%grind%') & (monday_pickup_hub !~ '%coffee%') & (monday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & (((monday_delivery_hub == nil))|((monday_delivery_hub !~ '%wanda%') & (monday_delivery_hub !~ '%bench%') & (monday_delivery_hub !~ '%grind%') & (monday_delivery_hub !~ '%coffee%') & (monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i }
            pause_next_monday_hub_unassigned = StopQueue.where(stop_type:"pause").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery) && ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_monday_hub_unassigned = StopQueue.where(stop_type:"cancel").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery) && ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            unpause_next_monday_hub_unassigned = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((recurring_delivery >> [nil,"No","no"]) & ((monday_pickup_hub == nil) | ((monday_pickup_hub !~ '%wanda%') & (monday_pickup_hub !~ '%bench%') & (monday_pickup_hub !~ '%grind%') & (monday_pickup_hub !~ '%coffee%') & (monday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & (((monday_delivery_hub == nil))|((monday_delivery_hub !~ '%wanda%') & (monday_delivery_hub !~ '%bench%') & (monday_delivery_hub !~ '%grind%') & (monday_delivery_hub !~ '%coffee%') & (monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            restarts_next_monday_hub_unassigned = StopQueue.where(stop_type:"restart").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery)&& ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_monday.to_i + q.customer.green_meals_on_monday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_monday_hub_unassigned = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.monday_pickup_hub == nil)| ((customers.monday_pickup_hub !~ '%wanda%') & (customers.monday_pickup_hub !~ '%bench%') & (customers.monday_pickup_hub !~ '%grind%') & (customers.monday_pickup_hub !~ '%coffee%') & (customers.monday_pickup_hub !~ '%dekefir%')))) | ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.monday_delivery_hub == nil))|((customers.monday_delivery_hub !~ '%wanda%') & (customers.monday_delivery_hub !~ '%bench%') & (customers.monday_delivery_hub !~ '%grind%') & (customers.monday_delivery_hub !~ '%coffee%') & (customers.monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i - e.customer.regular_meals_on_monday.to_i - e.customer.green_meals_on_monday.to_i}
            new_sign_ups_next_monday_hub_unassigned = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((recurring_delivery >> [nil,"No","no"]) & ((monday_pickup_hub == nil) | ((monday_pickup_hub !~ '%wanda%') & (monday_pickup_hub !~ '%bench%') & (monday_pickup_hub !~ '%grind%') & (monday_pickup_hub !~ '%coffee%') & (monday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & (((monday_delivery_hub == nil))|((monday_delivery_hub !~ '%wanda%') & (monday_delivery_hub !~ '%bench%') & (monday_delivery_hub !~ '%grind%') & (monday_delivery_hub !~ '%coffee%') & (monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum {|e| e.regular_meals_on_monday.to_i + e.green_meals_on_monday.to_i}
            hub_change_next_monday_hub_unassigned = - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.monday_pickup_hub == nil)|((customers.monday_pickup_hub !~ '%wanda%') & (customers.monday_pickup_hub !~ '%bench%') & (customers.monday_pickup_hub !~ '%grind%') & (customers.monday_pickup_hub !~ '%coffee%') & (customers.monday_pickup_hub !~ '%dekefir%'))))| ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.monday_delivery_hub == nil))|((customers.monday_delivery_hub !~ '%wanda%') & (customers.monday_delivery_hub !~ '%bench%') & (customers.monday_delivery_hub !~ '%grind%') & (customers.monday_delivery_hub !~ '%coffee%') & (customers.monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.updated_reg_mon.to_i + e.updated_grn_mon.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.monday_pickup_hub == nil)|((customers.monday_pickup_hub !~ '%wanda%') & (customers.monday_pickup_hub !~ '%bench%') & (customers.monday_pickup_hub !~ '%grind%') & (customers.monday_pickup_hub !~ '%coffee%') & (customers.monday_pickup_hub !~ '%dekefir%'))))| ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.monday_delivery_hub == nil))|((customers.monday_delivery_hub !~ '%wanda%') & (customers.monday_delivery_hub !~ '%bench%') & (customers.monday_delivery_hub !~ '%grind%') & (customers.monday_delivery_hub !~ '%coffee%') & (customers.monday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.customer.regular_meals_on_monday.to_i + e.customer.green_meals_on_monday.to_i} 

            hub_unassigned_meals_next_monday = monday_hub_unassigned - pause_next_monday_hub_unassigned - cancel_next_monday_hub_unassigned + unpause_next_monday_hub_unassigned + restarts_next_monday_hub_unassigned + meal_count_change_next_monday_hub_unassigned + new_sign_ups_next_monday_hub_unassigned + hub_change_next_monday_hub_unassigned

        elsif count_type == "hub_unassigned_meals_next_thursday"
            thursday_hub_unassigned = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == current_pick_up_date) & (((recurring_delivery >> [nil,"No","no"]) & ((thursday_pickup_hub == nil) | ((thursday_pickup_hub !~ '%wanda%') & (thursday_pickup_hub !~ '%bench%') & (thursday_pickup_hub !~ '%grind%') & (thursday_pickup_hub !~ '%coffee%') & (thursday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & (((thursday_delivery_hub == nil))|((thursday_delivery_hub !~ '%wanda%') & (thursday_delivery_hub !~ '%bench%') & (thursday_delivery_hub !~ '%grind%') & (thursday_delivery_hub !~ '%coffee%') & (thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i }
            pause_next_thursday_hub_unassigned = StopQueue.where(stop_type:"pause").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery) && ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            cancel_next_thursday_hub_unassigned = StopQueue.where(stop_type:"cancel").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery) && ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i           
            unpause_next_thursday_hub_unassigned = Customer.where{(paused? >> ["Yes","yes"]) & (pause_end_date >> [Chowdy::Application.closest_date(1,0,current_pick_up_date),Chowdy::Application.closest_date(1,1,current_pick_up_date)]) & (((recurring_delivery >> [nil,"No","no"]) & ((thursday_pickup_hub == nil)|((thursday_pickup_hub !~ '%wanda%') & (thursday_pickup_hub !~ '%bench%') & (thursday_pickup_hub !~ '%grind%') & (thursday_pickup_hub !~ '%coffee%') & (thursday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & ((thursday_delivery_hub == nil)|((thursday_delivery_hub !~ '%wanda%') & (thursday_delivery_hub !~ '%bench%') & (thursday_delivery_hub !~ '%grind%') & (thursday_delivery_hub !~ '%coffee%') & (thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}    
            restarts_next_thursday_hub_unassigned = StopQueue.where(stop_type:"restart").map {|q| if (([nil,"No","no"].include? q.customer.recurring_delivery) && ((q.customer.monday_pickup_hub.match(/wanda/i).nil?) && (q.customer.monday_pickup_hub.match(/bench/i).nil?) && (q.customer.monday_pickup_hub.match(/grind/i).nil?) && (q.customer.monday_pickup_hub.match(/coffee/i).nil?) && (q.customer.monday_pickup_hub.match(/dekefir/i).nil?))) || ((["Yes","yes"].include? q.customer.recurring_delivery) && ((q.customer.monday_delivery_hub.match(/wanda/i).nil?) && (q.customer.monday_delivery_hub.match(/bench/i).nil?) && (q.customer.monday_delivery_hub.match(/grind/i).nil?) && (q.customer.monday_delivery_hub.match(/coffee/i).nil?) && (q.customer.monday_delivery_hub.match(/dekefir/i).nil?))) ; q.customer.regular_meals_on_thursday.to_i + q.customer.green_meals_on_thursday.to_i else 0 end }.inject {|sum, x| sum + x}.to_i
            meal_count_change_next_thursday_hub_unassigned = StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_sub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.thursday_pickup_hub == nil)| ((customers.thursday_pickup_hub !~ '%wanda%') & (customers.thursday_pickup_hub !~ '%bench%') & (customers.thursday_pickup_hub !~ '%grind%') & (customers.thursday_pickup_hub !~ '%coffee%') & (customers.thursday_pickup_hub !~ '%dekefir%')))) | ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.thursday_delivery_hub == nil))|((customers.thursday_delivery_hub !~ '%wanda%') & (customers.thursday_delivery_hub !~ '%bench%') & (customers.thursday_delivery_hub !~ '%grind%') & (customers.thursday_delivery_hub !~ '%coffee%') & (customers.thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i - e.customer.regular_meals_on_thursday.to_i - e.customer.green_meals_on_thursday.to_i}
            new_sign_ups_next_thursday_hub_unassigned = Customer.where{(active? >> ["Yes","yes"]) & (next_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (first_pick_up_date == Chowdy::Application.closest_date(1,1,current_pick_up_date)) & (((recurring_delivery >> [nil,"No","no"]) & ((thursday_pickup_hub == nil) | ((thursday_pickup_hub !~ '%wanda%') & (thursday_pickup_hub !~ '%bench%') & (thursday_pickup_hub !~ '%grind%') & (thursday_pickup_hub !~ '%coffee%') & (thursday_pickup_hub !~ '%dekefir%')))) | ((recurring_delivery >> ["Yes","yes"]) & (((thursday_delivery_hub == nil))|((thursday_delivery_hub !~ '%wanda%') & (thursday_delivery_hub !~ '%bench%') & (thursday_delivery_hub !~ '%grind%') & (thursday_delivery_hub !~ '%coffee%') & (thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum {|e| e.regular_meals_on_thursday.to_i + e.green_meals_on_thursday.to_i}
            hub_change_next_thursday_hub_unassigned =  - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id >> StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.thursday_pickup_hub == nil)|((customers.thursday_pickup_hub !~ '%wanda%') & (customers.thursday_pickup_hub !~ '%bench%') & (customers.thursday_pickup_hub !~ '%grind%') & (customers.thursday_pickup_hub !~ '%coffee%') & (customers.thursday_pickup_hub !~ '%dekefir%'))))| ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.thursday_delivery_hub == nil))|((customers.thursday_delivery_hub !~ '%wanda%') & (customers.thursday_delivery_hub !~ '%bench%') & (customers.thursday_delivery_hub !~ '%grind%') & (customers.thursday_delivery_hub !~ '%coffee%') & (customers.thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.updated_reg_thu.to_i + e.updated_grn_thu.to_i} - StopQueue.joins{customer}.where{(stop_queues.stop_type =~ "change_hub") & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["pause","cancel"]).map {|s| s.stripe_customer_id}) & (stop_queues.stripe_customer_id << StopQueue.where(stop_type:["change_sub"]).map {|s| s.stripe_customer_id}) & (((customers.recurring_delivery >> [nil,"No","no"]) & ((customers.thursday_pickup_hub == nil)|((customers.thursday_pickup_hub !~ '%wanda%') & (customers.thursday_pickup_hub !~ '%bench%') & (customers.thursday_pickup_hub !~ '%grind%') & (customers.thursday_pickup_hub !~ '%coffee%') & (customers.thursday_pickup_hub !~ '%dekefir%'))))| ((customers.recurring_delivery >> ["Yes","yes"]) & (((customers.thursday_delivery_hub == nil))|((customers.thursday_delivery_hub !~ '%wanda%') & (customers.thursday_delivery_hub !~ '%bench%') & (customers.thursday_delivery_hub !~ '%grind%') & (customers.thursday_delivery_hub !~ '%coffee%') & (customers.thursday_delivery_hub !~ '%dekefir%')))))}.to_a.sum{|e| e.customer.regular_meals_on_thursday.to_i + e.customer.green_meals_on_thursday.to_i} 

            hub_unassigned_meals_next_thursday = thursday_hub_unassigned - pause_next_thursday_hub_unassigned - cancel_next_thursday_hub_unassigned + unpause_next_thursday_hub_unassigned + restarts_next_thursday_hub_unassigned + meal_count_change_next_thursday_hub_unassigned + new_sign_ups_next_thursday_hub_unassigned + hub_change_next_thursday_hub_unassigned

        elsif count_type == "gta_selected_beef_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "gta_selected_poultry_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "gta_selected_pork_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "gta_selected_salad_bowl_1_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_1)
        elsif count_type == "gta_selected_salad_bowl_2_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_2)
        elsif count_type == "gta_selected_diet_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:diet)
        elsif count_type == "gta_selected_chefs_special_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:chefs_special)
        elsif count_type == "gta_selected_green_1_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "gta_selected_green_2_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "gta_not_selected_regular_monday"
            active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{(customers.recurring_delivery >> ["Yes","yes"]) & (customers.monday_delivery_hub =~ '%gta%') & (meal_selections.id == nil)}.sum(:regular_meals_on_monday)
        elsif count_type == "gta_not_selected_green_monday"
            active_nonpaused_customers.joins{current_week_monday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{(customers.recurring_delivery >> ["Yes","yes"]) & (customers.monday_delivery_hub =~ '%gta%') & (meal_selections.id == nil)}.sum(:green_meals_on_monday)
        elsif count_type == "coffee_bar_selected_beef_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "coffee_bar_selected_poultry_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "coffee_bar_selected_pork_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "coffee_bar_selected_salad_bowl_1_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_1)
        elsif count_type == "coffee_bar_selected_salad_bowl_2_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_2)
        elsif count_type == "coffee_bar_selected_diet_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:diet)
        elsif count_type == "coffee_bar_selected_chefs_special_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:chefs_special)
        elsif count_type == "coffee_bar_selected_green_1_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "coffee_bar_selected_green_2_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "wandas_selected_beef_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "wandas_selected_poultry_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "wandas_selected_pork_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "wandas_selected_green_1_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "wandas_selected_green_2_monday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_1) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "gta_selected_beef_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "gta_selected_poultry_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "gta_selected_pork_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "gta_selected_salad_bowl_1_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_1)
        elsif count_type == "gta_selected_salad_bowl_2_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_2)
        elsif count_type == "gta_selected_diet_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:diet)
        elsif count_type == "gta_selected_chefs_special_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:chefs_special)
        elsif count_type == "gta_selected_green_1_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "gta_selected_green_2_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%gta%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "gta_not_selected_regular_thursday"
            active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{(customers.recurring_delivery >> ["Yes","yes"]) & (customers.monday_delivery_hub =~ '%gta%') & (meal_selections.id == nil)}.sum(:regular_meals_on_thursday)
        elsif count_type == "gta_not_selected_green_thursday"
            active_nonpaused_customers.joins{current_week_thursday_selected.as('meal_selections').on{stripe_customer_id == meal_selections.stripe_customer_id}.outer}.where{(customers.recurring_delivery >> ["Yes","yes"]) & (customers.monday_delivery_hub =~ '%gta%') & (meal_selections.id == nil)}.sum(:green_meals_on_thursday)
        elsif count_type == "coffee_bar_selected_beef_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "coffee_bar_selected_poultry_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "coffee_bar_selected_pork_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "coffee_bar_selected_salad_bowl_1_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_1)
        elsif count_type == "coffee_bar_selected_salad_bowl_2_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:salad_bowl_2)
        elsif count_type == "coffee_bar_selected_diet_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:diet)
        elsif count_type == "coffee_bar_selected_chefs_special_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:chefs_special)
        elsif count_type == "coffee_bar_selected_green_1_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "coffee_bar_selected_green_2_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%coffee%bar%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "wandas_selected_beef_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:beef)
        elsif count_type == "wandas_selected_poultry_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:poultry)
        elsif count_type == "wandas_selected_pork_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:pork)
        elsif count_type == "wandas_selected_green_1_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_1)
        elsif count_type == "wandas_selected_green_2_thursday"
            MealSelection.joins{customer}.where{(meal_selections.production_day == production_day_2) & (customers.monday_delivery_hub =~ '%wanda%') & (customers.recurring_delivery >> ["Yes","yes"]) & (customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date)}.sum(:green_2)
        elsif count_type == "selected_beef_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:beef)
        elsif count_type == "selected_pork_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:pork)
        elsif count_type == "selected_poultry_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:poultry)
        elsif count_type == "selected_salad_bowl_1_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:salad_bowl_1)
        elsif count_type == "selected_salad_bowl_2_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:salad_bowl_2)
        elsif count_type == "selected_diet_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:diet)
        elsif count_type == "selected_chefs_special_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:chefs_special)
        elsif count_type == "selected_green_1_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:green_1)
        elsif count_type == "selected_green_2_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:green_2)
        elsif count_type == "selected_beef_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:beef)
        elsif count_type == "selected_pork_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:pork)
        elsif count_type == "selected_poultry_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:poultry)
        elsif count_type == "selected_salad_bowl_1_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:salad_bowl_1)
        elsif count_type == "selected_salad_bowl_2_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:salad_bowl_2)
        elsif count_type == "selected_diet_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:diet)
        elsif count_type == "selected_chefs_special_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:chefs_special)
        elsif count_type == "selected_green_1_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:green_1)
        elsif count_type == "selected_green_2_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.sum(:green_2)
        elsif count_type == "not_selected_regular_adjustment_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.inject(0) {|sum, ms| sum + (ms.customer.stop_queues.where(stop_type:"change_sub").blank? ? ms.customer.regular_meals_on_monday.to_i : ms.customer.stop_queues.where(stop_type:"change_sub").take.updated_reg_mon.to_i) }
        elsif count_type == "not_selected_green_adjustment_next_monday"
            production_day_1 = Chowdy::Application.closest_date(-1,7,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_1) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.inject(0) {|sum, ms| sum + (ms.customer.stop_queues.where(stop_type:"change_sub").blank? ? ms.customer.green_meals_on_monday.to_i : ms.customer.stop_queues.where(stop_type:"change_sub").take.updated_grn_mon.to_i) }
        elsif count_type == "not_selected_regular_adjustment_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.inject(0) {|sum, ms| sum + (ms.customer.stop_queues.where(stop_type:"change_sub").blank? ? ms.customer.regular_meals_on_thursday.to_i : ms.customer.stop_queues.where(stop_type:"change_sub").take.updated_reg_thu.to_i) }
        elsif count_type == "not_selected_green_adjustment_next_thursday"
            production_day_2 = Chowdy::Application.closest_date(1,3,Chowdy::Application.closest_date(1,7,current_pick_up_date))
            MealSelection.joins{customer.stop_queues.outer}.where{(meal_selections.production_day == production_day_2) & (customers.recurring_delivery >> ["Yes","yes"]) & (((customers.active? >> ["Yes","yes"]) & (customers.paused? >> [nil,"No","no"]) & (customers.next_pick_up_date == current_pick_up_date) & (stop_queues.stop_type >> [nil, "change_sub","change_hub","restart"])) | (((customers.active? >> [nil,"No","no"]) | (customers.paused? >> ["Yes","yes"])) & (stop_queues.stop_type >> ["restart"])))}.inject(0) {|sum, ms| sum + (ms.customer.stop_queues.where(stop_type:"change_sub").blank? ? ms.customer.green_meals_on_thursday.to_i : ms.customer.stop_queues.where(stop_type:"change_sub").take.updated_grn_thu.to_i) }
        end
    end

end
