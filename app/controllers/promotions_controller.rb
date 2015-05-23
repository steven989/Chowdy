class PromotionsController < ApplicationController

  def new
    @promotion = Promotion.new

    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def create
    promotion = Promotion.new(promotion_params)
    code = params[:promotion][:code]
    amount = params[:promotion][:amount_in_cents]

    if (Promotion.all.map {|p| p.code}.include? code) || (amount.blank?) || (code.blank?) || (Customer.all.map {|c| c.referral_code}.include? code)
        redirect_to user_profile_path+"#promotions"
    else 
        stripe_coupon = Stripe::Coupon.create(amount_off:amount, duration:"once", currency:"CAD",id: params[:promotion][:code])
        if stripe_coupon
            promotion.save
            promotion.update_attribute(:stripe_coupon_id, stripe_coupon.id)
        end

        redirect_to user_profile_path+"#promotions"
    end  
  end

  def edit
    @promotion = Promotion.find(params[:id])
    respond_to do |format|
      format.html {
        render partial: 'form'
      }
    end
  end

  def activate
    promotion = Promotion.find(params[:id])
    
    if promotion.active == true
        promotion.update_attributes(active:false, end_date: Date.today)
    else 
        promotion.update_attributes(active:true, end_date: nil, start_date: Date.today)
    end
    redirect_to user_profile_path+"#promotions"
  end

  def update
    promotion = Promotion.find(params[:id])
    promotion.update_attributes(promotion_params)

    redirect_to user_profile_path+"#promotions"
  end

  def destroy
    promotion = Promotion.find(params[:id])
    
    if promotion.stripe_coupon_id.blank?
        promotion.destroy
    else
        if Stripe::Coupon.retrieve(promotion.stripe_coupon_id).delete
            promotion.destroy
        end
    end
    redirect_to user_profile_path+"#promotions"
  end

  private

  def promotion_params
    params.require(:promotion).permit(:start_date,:end_date,:code,:stripe_coupon_id,:immediate_refund,:amount_in_cents)
  end


end
