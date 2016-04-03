class PartnerProductDeliveryDatesController < ApplicationController

    def edit
        @delivery_date = PartnerProductDeliveryDate.first
        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end
    end

    def update
       @delivery_date = PartnerProductDeliveryDate.first
       @delivery_date.update_attributes(delivery_date: params[:partner_product_delivery_date][:delivery_date]) 
       redirect_to user_profile_path+"#partner_products"
    end

end
