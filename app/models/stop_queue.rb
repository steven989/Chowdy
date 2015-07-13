class StopQueue < ActiveRecord::Base
    belongs_to :customer, foreign_key: :stripe_customer_id, primary_key: :stripe_customer_id


    def add_to_record
        StopQueueRecord.create(
        associated_cutoff: self.associated_cutoff,
        stop_type: self.stop_type,
        stripe_customer_id: self.stripe_customer_id,
        end_date: self.end_date,
        start_date: self.start_date,
        updated_meals: self.updated_meals,
        updated_reg_mon: self.updated_reg_mon,
        updated_reg_thu: self.updated_reg_thu,
        updated_grn_mon: self.updated_grn_mon,
        updated_grn_thu: self.updated_grn_thu,
        cancel_reason: self.cancel_reason,
        queue_created_at: self.created_at,
        queue_updated_at: self.updated_at
        )
    end

end
