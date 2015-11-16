class GiftsController < ApplicationController
    def view_redemption
        gift = Gift.find(params[:id])
        if gift
            @gift_redemptions = gift.gift_redemptions.order(created_at: :asc)
        else
            @gift_redemptions = nil
        end

        respond_to do |format|
          format.html {
            render partial: 'view_gift_redemptions'
          }
        end  
    end
end
