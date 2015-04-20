class CustomersController < ApplicationController

    def create #create customer account through Stripe webhook
        #use customer.created hook
        #system to update the trial end date in stripe using the StartDate model
        #check for potential duplicate payment and send report
    end

    # def stripe_update #change customer account information through Stripe webhook
    #     #meal count (use customer.subscription.updated hook)
    #     #pause (use customer.subscription.updated hook)
    #     #active/inactive (use customer.subscription.deleted hook)
    # end

    def update #change customer account information from website
        #affect stripe
            #meal count (change plan in Stripe)      
            #pause (change trial date)
            #active/inactive (add/delete subscriptions; new subscriptions to have trial end date associated with it)
        #all database fields
    end

    def fail #failed charges
        #generate report (use charge.failed hook)
    end

    def stripe_destroy #delete customer account through Stripe webhook
        #delete on system and Stripe
    end

end
