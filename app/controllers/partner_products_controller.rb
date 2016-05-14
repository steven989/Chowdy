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


    def show
      @partner_product = PartnerProduct.find(params[:id])
      @photos = @partner_product.photos
      @disable_markplace_purchase =  SystemSetting.where(setting:"marketplace",setting_attribute:"order").blank? ? true : (SystemSetting.where(setting:"marketplace",setting_attribute:"order").take.setting_value == "true" ? false : true)
      respond_to do |format|
        format.html {
          render partial: 'show'
        }
      end
    end

    def paginate
      @parter_products = Kaminari.paginate_array(PartnerProduct.products_to_display).page(params[:page])
      @page = params[:page]
      @parter_products_menu = @parter_products.map{|pp| {product_id:pp.id, price:pp.price_in_cents, name:pp.product_name, description:pp.product_description}}
      @disable_markplace_purchase =  SystemSetting.where(setting:"marketplace",setting_attribute:"order").blank? ? true : (SystemSetting.where(setting:"marketplace",setting_attribute:"order").take.setting_value == "true" ? false : true)

      respond_to do |format|
        format.js {
          render partial: 'paginate'
        }
      end
    end


    def new
        @vendor = Vendor.where(id: params[:vendor_id]).take
        @partner_product = @vendor.partner_products.new
        @method = "POST"

        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end  
    end

    def create
        vendor = Vendor.where(id:params[:partner_product][:vendor_id]).take
        partner_product = vendor.partner_products.new(partner_product_params)
        partner_product.photos = params[:photos].values unless params[:photos].blank?

        if partner_product.save

          if params[:partner_product][:position].blank? 
            partner_product.insert_at(1)
          elsif params[:partner_product][:position].to_i == -1
            partner_product.move_to_bottom
          else 
            partner_product.insert_at(params[:partner_product][:position].to_i)
          end
          
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
        @method = "PUT"
        @vendor = Vendor.where(id: params[:vendor_id]).take
        @partner_product = PartnerProduct.find(params[:id])
        @photos_exist = @partner_product.photos?
        @photos = @partner_product.photos
        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end    
    end

    def update
        partner_product = PartnerProduct.where(id:params[:id]).take
        partner_product.assign_attributes(partner_product_params)
        partner_product.photos = params[:photos].values unless params[:photos].blank?

        if partner_product.save

          if params[:partner_product][:position].blank? 
            partner_product.insert_at(1)
          elsif params[:partner_product][:position].to_i == -1
            partner_product.move_to_bottom
          else 
            partner_product.insert_at(params[:partner_product][:position].to_i)
          end

          status = "success"
          notice_partner_product = "Partner product updated"
        else
          status = "fail"
          notice_partner_product = "Partner product could not be updated: #{partner_product.errors.full_messages.join(", ")}"
        end

        respond_to do |format|
          format.json {
            render json: {status:status, message:notice_partner_product}
          } 
        end         
    end

    def remove_photos
      partner_product = PartnerProduct.find(params[:id])
      partner_product.remove_photos!
      if partner_product.save
        status = "success"
        notice_partner_product = "Photos successfully removed"
      else
        status = "fail"
        notice_partner_product = "Photos could not be removed: #{partner_product.errors.full_messages.join(', ')}"
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
      params.require(:partner_product).permit(:vendor_id,:product_id,:product_name,:product_description,:product_size,:vendor_product_sku,:vendor_product_upc,:cost_in_cents,:suggested_retail_price_in_cents,:price_in_cents,:max_quantity,:available)
    end


end
