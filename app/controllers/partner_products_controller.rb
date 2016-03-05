class PartnerProductsController < ApplicationController
    

    def index
        @vendor = Vendor.where(id: params[:vendor_id]).take
        @vendor_products = @vendor.partner_products.order(created_at: :asc)

        respond_to do |format|
          format.html {
            render partial: 'table'
          }
        end      
    end

    def new
        @vendor = Vendor.where(id: params[:vendor_id]).take
        @partner_product = @vendor.partner_products.new

        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end  
    end

    def create
        vendor = Vendor.where(id:params[:partner_product][:vendor_id]).take
        partner_product = vendor.partner_products.new(partner_product_params)
        partner_product.photos = params[:photos].values

        if partner_product.save
          status = "success"
          notice_partner_product = "Partner product created"
        else
          status = "fail"
          notice_partner_product = "Parner product could not be created: #{partner_product.errors.full_messages.join(", ")}"
        end 

        respond_to do |format|
          format.json {
            render json: {status:status, message:notice_partner_product}
          } 
        end 
    end

    def edit
        @edit = true
        @vendor = Vendor.where(id: params[:vendor_id]).take
        @partner_product = PartnerProduct.find(params[:id])
        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end    
    end

    def update
        partner_product = PartnerProduct.where(id:params[:id]).take
        partner_product.update_attributes(partner_product_params)

        if partner_product.errors.any?
          status = "fail"
          notice_partner_product = "Partner product could not be updated: #{partner_product.errors.full_messages.join(", ")}"
        else
          status = "success"
          notice_partner_product = "Partner product updated"
        end

        respond_to do |format|
          format.json {
            render json: {status:status, message:notice_partner_product}
          } 
        end         
    end

    def destroy
        partner_product = PartnerProduct.find(params[:id])
        if partner_product.destroy
          flash[:status] = "success"
          flash[:notice_partner_products] = "Partner product deleted"
        else
          flash[:status] = "fail"
          flash[:notice_partner_products] = "Partner product could not be deleted: #{vendor.errors.full_messages.join(", ")}"
        end

        redirect_to user_profile_path+"#partner_products"        
    end

    private

    def partner_product_params
      params.require(:partner_product).permit(:vendor_id,:product_id,:product_name,:product_description,:product_size,:vendor_product_sku,:vendor_product_upc,:cost_in_cents,:suggested_retail_price_in_cents,:price_in_cents)
    end


end
