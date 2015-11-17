class GiftsController < ApplicationController
    def view_redemption
        @gift = Gift.find(params[:id])
        if @gift
            @gift_redemptions = @gift.gift_redemptions.order(created_at: :asc)
        else
            @gift_redemptions = nil
        end

        respond_to do |format|
          format.html {
            render partial: 'view_gift_redemptions'
          }
        end  
    end

    def resend_sender_confirmation_form
        @person = "sender"
        @gift = Gift.find(params[:id])
        @post_path = resend_sender_confirmation_path(@gift)
        @prepopulated_email = @gift.sender_email
        respond_to do |format|
          format.html {
            render partial: 'get_email_address'
          } 
        end       
    end

    def resend_recipient_confirmation_form
        @person = "recipient"
        @gift = Gift.find(params[:id])
        @post_path = resend_recipient_confirmation_path(@gift)
        @prepopulated_email = @gift.recipient_email
        respond_to do |format|
          format.html {
            render partial: 'get_email_address'
          } 
        end          
    end

    def resend_sender_confirmation
        
        begin
            gift = Gift.find(params[:id])
            target_email = params[:target_email].blank? ? nil : params[:target_email]
            CustomerMailer.delay.gift_sender_confirmation(gift,target_email)
        rescue => error 
            status = "fail"
            message = error.message
        else
            status = "success"
            message = "test"
        end
        
        respond_to do |format|
          format.json {
            render json: {status:status, message:message}
          } 
        end           
    end

    def resend_recipient_confirmation

        begin
            gift = Gift.find(params[:id])
            target_email = params[:target_email].blank? ? nil : params[:target_email]
            CustomerMailer.delay.gift_recipient_notification(gift,target_email)
        rescue => error 
            status = "fail"
            message = error.message
        else
            status = "success"
            message = "test"
        end
        
        respond_to do |format|
          format.json {
            render json: {status:status, message:message}
          } 
        end    

    end
end
