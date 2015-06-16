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
        flash[:status] = "fail"
        flash[:notice_promotions] = "Promotion cannot be creaetd. Either code or amount is missing, or code already exisits. It could also be matching an existing customer's referral code."

        redirect_to user_profile_path+"#promotions"
    else 
      begin
        stripe_coupon = Stripe::Coupon.create(amount_off:amount, duration:"once", currency:"CAD",id: params[:promotion][:code])
        if stripe_coupon
            promotion.save
            promotion.update_attribute(:stripe_coupon_id, stripe_coupon.id)
        end
      rescue => error
        flash[:status] = "fail"
        flash[:notice_promotions] = "Error occurred while creating the promotional coupon on Stripe: #{error.message}"
        puts '---------------------------------------------------'
        puts "Error occurred while creating the promotional coupon on Stripe: #{error.message}"
        puts '---------------------------------------------------'
      else
        if promotion.errors.any?
          flash[:status] = "fail"
          flash[:notice_promotions] = "Promotion could not be created: #{promotion.errors.full_messages.join(", ")}"
        else
          flash[:status] = "success"
          flash[:notice_promotions] = "Promotion created"          
        end
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

    if promotion.errors.any?
      flash[:status] = "fail"
      flash[:notice_promotions] = "Promotion could not be updated: #{promotion.errors.full_messages.join(", ")}"
    else
      flash[:status] = "success"
      flash[:notice_promotions] = "Promotion updated"          
    end

    redirect_to user_profile_path+"#promotions"
  end

  def destroy
    promotion = Promotion.find(params[:id])
    
    if promotion.stripe_coupon_id.blank?
        if promotion.destroy
          flash[:status] = "success"
          flash[:notice_promotions] = "Promotion deleted"          
        else
          flash[:status] = "fail"
          flash[:notice_promotions] = "Promotion could not be deleted: #{promotion.errors.full_messages.join(", ")}"
        end
    else
        begin 
          Stripe::Coupon.retrieve(promotion.stripe_coupon_id).delete
        rescue => error
          flash[:status] = "fail"
          flash[:notice_promotions] = "Error occurred while deleting the promotional coupon on Stripe: #{error.message}"
          puts '---------------------------------------------------'
          puts "Error occurred while deleting the promotional coupon on Stripe: #{error.message}"
          puts '---------------------------------------------------'
        else
          if promotion.destroy
            flash[:status] = "success"
            flash[:notice_promotions] = "Promotion deleted"          
          else
            flash[:status] = "fail"
            flash[:notice_promotions] = "Promotion could not be deleted: #{promotion.errors.full_messages.join(", ")}"
          end
        end
    end
    redirect_to user_profile_path+"#promotions"
  end

  private

  def promotion_params
    params.require(:promotion).permit(:start_date,:end_date,:code,:stripe_coupon_id,:immediate_refund,:amount_in_cents)
  end


end
