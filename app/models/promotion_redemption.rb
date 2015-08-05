class PromotionRedemption < ActiveRecord::Base
    belongs_to :customer, primary_key: :stripe_customer_id, foreign_key: :stripe_customer_id
    belongs_to :promotion

    def self.check_eligibility(customer,promo_code)
        if Promotion.where("code ilike ?", promo_code.gsub(" ","")).length > 0
            if Promotion.where("code ilike ? and active = true", promo_code.gsub(" ","")).length == 0 
                {result:false, message:'Promotion is not active'}
            elsif Promotion.where("code ilike ? and active = true", promo_code.gsub(" ","")).length > 1
                {result:false, message:'Multiple active promotions'}
            else
                promotion = Promotion.where("code ilike ? and active = true", promo_code.gsub(" ","")).take
                if customer.promotion_redemptions.map {|pr| pr.promotion_id}.include? promotion.id
                    {result:false, message:'You already applied this promo code'}
                elsif (promotion.new_customer_only) && ((customer.created_at) < (14.days.ago))
                    {result:false, message:'This promo is available to new customers only'}
                else
                    if (["No","no",nil].include? customer.active?) || (customer.stripe_subscription_id.blank?)
                        {result:false, message:'Promo code cannot be applied as you do not current have an active subscription'}
                    else
                        if promotion.immediate_refund?
                            {result:true, message:"Promo code applied. $#{promotion.amount_in_cents/100} will be refunded to you shortly"}
                        else
                            {result:true, message:"Promo code applied. $#{promotion.amount_in_cents/100} discount will be applied to your next bill"}
                        end

                    end
                end
            end
        else
            {result:false, message:'Promotion not found'}
        end        
    end

    def self.redeem(customer,promo_code)
        begin
            promotion = Promotion.where("code ilike ? and active = true", promo_code.gsub(" ","")).take
            if promotion.immediate_refund
                recent_charges = Stripe::Charge.all(customer:customer.stripe_customer_id, limit:20).data.inject([]) do |array, data| array.push(data.id) end
                amount = promotion.amount_in_cents
                refund_list = []
                recent_charges.each do |charge_id|
                    charge = Stripe::Charge.retrieve(charge_id)
                    net_amount = charge.amount - charge.amount_refunded
                    if net_amount - amount >= 0
                        refund_list.push({charge_id.to_sym => amount})
                        break
                    else
                        refund_list.push({charge_id.to_sym => net_amount}) unless net_amount == 0
                        amount -= net_amount
                    end
                end

                refund_week = SystemSetting.where(setting:"system_date", setting_attribute:"pick_up_date").take.setting_value.to_date
                internal_refund_id = nil
                refund_list.each do |refund_li|
                    charge_id = refund_li.keys[0].to_s
                    list_refund_amount = refund_li.values[0]
                    charge = Stripe::Charge.retrieve(charge_id)

                    if stripe_refund_response = charge.refunds.create(amount:list_refund_amount) 
                        newly_created_refund = Refund.create(stripe_customer_id: customer.stripe_customer_id, refund_week:refund_week, charge_week:Time.at(charge.created).to_date,charge_id: charge.id, meals_refunded:nil, amount_refunded: list_refund_amount, refund_reason: "Promo code: #{promotion.code}", stripe_refund_id: stripe_refund_response.id)
                        newly_created_refund.internal_refund_id = internal_refund_id.nil? ? newly_created_refund.id : internal_refund_id
                        if newly_created_refund.save
                            internal_refund_id ||= newly_created_refund.id
                        end
                    end   
                end

                promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
            else 
                stripe_subscription = Stripe::Customer.retrieve(customer.stripe_customer_id).subscriptions.retrieve(customer.stripe_subscription_id)

                stripe_subscription.coupon = promotion.stripe_coupon_id
                stripe_subscription.prorate = false
                if stripe_subscription.save
                    promotion.update_attribute(:redemptions, promotion.redemptions.to_i + 1)
                end
            end
        rescue => error
            puts '---------------------------------------------------'
            puts "Promotion could not be applied"
            puts error.message
            puts '---------------------------------------------------'
            CustomerMailer.rescued_error(customer,"Promotion could not be applied: "+error.message).deliver            
            {result:false, message:'Issue with applying the code'}
        else
            PromotionRedemption.create(stripe_customer_id:customer.stripe_customer_id,promotion_id:promotion.id)
            {result:true, message:'Promo code applied'}
        end

    end

end
