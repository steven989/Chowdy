class VendorsController < ApplicationController
    def new
        @vendor = Vendor.new

        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end
    end

    def create
        vendor = Vendor.new(vendor_params)
        if vendor.save
        vendor.create_external_vendor_id
          flash[:status] = "success"
          flash[:notice_partner_products] = "Vendor created"
        else
          flash[:status] = "fail"
          flash[:notice_partner_products] = "Vendor could not be created: #{vendor.errors.full_messages.join(", ")}"
        end
        redirect_to user_profile_path+"#partner_products"
    end

    def edit
        @vendor = Vendor.find(params[:id])
        respond_to do |format|
          format.html {
            render partial: 'form'
          }
        end        
    end

    def update
        vendor = Vendor.find(params[:id])
        vendor.update_attributes(vendor_params)

        if vendor.errors.any?
          flash[:status] = "fail"
          flash[:notice_partner_products] = "Vendor could not be updated: #{vendor.errors.full_messages.join(", ")}"
        else
          flash[:status] = "success"
          flash[:notice_partner_products] = "Vendor updated"
        end

        redirect_to user_profile_path+"#partner_products"        
    end

    def destroy
        vendor = Vendor.find(params[:id])
        if vendor.destroy
          flash[:status] = "success"
          flash[:notice_partner_products] = "Vendor deleted"
        else
          flash[:status] = "fail"
          flash[:notice_partner_products] = "Vendor could not be deleted: #{vendor.errors.full_messages.join(", ")}"
        end

        redirect_to user_profile_path+"#partner_products"
    end

    private

    def vendor_params
        params.require(:vendor).permit(:vendor_name,:vendor_description,:contact_name,:phone_number,:email_address,:alt_contact_name,:alt_phone_number,:alt_email_address,:vendor_address,:alt_vendor_address)        
    end

end
