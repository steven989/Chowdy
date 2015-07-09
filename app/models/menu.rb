class Menu < ActiveRecord::Base
    has_many :menu_ratings

    def refresh_rating
        number_of_ratings = self.menu_ratings.length
        average_rating = ((self.menu_ratings.sum(:rating).to_f/self.menu_ratings.length.to_f) * 100).round / 100.0
        self.update_attributes(average_score:average_rating,number_of_scores:number_of_ratings)        
    end

end
