class MenuRating < ActiveRecord::Base
    belongs_to :menu
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id

    def self.refresh_score
        
    end

end
