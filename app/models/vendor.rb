class Vendor < ActiveRecord::Base
    has_many :partner_products

    def create_external_vendor_id
        vendor_name = self.vendor_name
        five_digit = rand(1000..9999).to_s
        id_text = vendor_name.gsub(/\s+/, "").gsub(/[^0-9A-Za-z]/, '').upcase[0..3]
        id_candidate = id_text + five_digit

        while Vendor.where(ext_vendor_id: id_candidate).length > 0 do
            five_digit = rand(1000..9999).to_s
            id_text = vendor_name.gsub(/\s+/, "").gsub(/[^0-9A-Za-z]/, '').upcase[1..4]
            id_candidate = id_text + five_digit
        end

        self.update_attribute(:ext_vendor_id, id_candidate)

    end
end
