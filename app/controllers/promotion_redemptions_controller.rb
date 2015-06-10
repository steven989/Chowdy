class PromotionRedemptionsController < ApplicationController

    def redeem
        check_result = PromotionRedemption.check_eligibility(current_customer,params[:promo_code])
        if check_result[:result]
            PromotionRedemption.delay.redeem(current_customer,params[:promo_code])
            flash[:status] = check_result[:result] ? "success" : "fail"
            flash[:notice_referral] = check_result[:message]
        else
            flash[:status] = check_result[:result] ? "success" : "fail"
            flash[:notice_referral] = check_result[:message]            
        end
        redirect_to user_profile_path+"#referral"
    end

end
