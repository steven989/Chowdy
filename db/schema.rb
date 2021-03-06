# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.


ActiveRecord::Schema.define(version: 20160715160549) do


  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "authentications", force: :cascade do |t|
    t.integer  "user_id",                null: false
    t.string   "provider",   limit: 255, null: false
    t.string   "uid",        limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name",                                 limit: 255
    t.string   "gender",                               limit: 255
    t.string   "race",                                 limit: 255
    t.string   "phone_number",                         limit: 255
    t.string   "hub",                                  limit: 255
    t.string   "hub_note",                             limit: 255
    t.string   "purchase",                             limit: 255
    t.string   "active?",                              limit: 255
    t.date     "first_pick_up_date"
    t.date     "last_pick_up_date"
    t.integer  "total_meals_per_week"
    t.integer  "number_of_green"
    t.integer  "number_of_plus"
    t.date     "latest_chowdy_plus_bill_week"
    t.date     "next_pick_up_date"
    t.integer  "monday_regular_meal_count_override"
    t.integer  "thursday_regular_meal_count_override"
    t.integer  "monday_green_meal_count_override"
    t.integer  "thursday_green_meal_count_override"
    t.integer  "monday_plus_meal_count_override"
    t.integer  "thursday_plus_meal_count_override"
    t.integer  "regular_meals_on_monday"
    t.integer  "green_meals_on_monday"
    t.integer  "plus_meals_on_monday"
    t.integer  "regular_meals_on_thursday"
    t.integer  "green_meals_on_thursday"
    t.integer  "plus_meals_on_thursday"
    t.string   "paused?",                              limit: 255
    t.date     "pause_start_date"
    t.date     "pause_end_date"
    t.string   "openmat_member?",                      limit: 255
    t.string   "one_time_fee_paid?",                   limit: 255
    t.string   "referral",                             limit: 255
    t.integer  "referral_bonus_referrer"
    t.integer  "referral_bonus_referree"
    t.integer  "referral_bonus_paid"
    t.date     "date_signed_up_for_recurring"
    t.date     "date_cancelled"
    t.string   "pause_cancel_request",                 limit: 255
    t.string   "cancellation_reason",                  limit: 255
    t.text     "notes"
    t.string   "meal_preferences",                     limit: 255
    t.date     "last_surveyed"
    t.string   "recurring_delivery",                   limit: 255
    t.string   "delivery_address",                     limit: 255
    t.string   "delivery_time",                        limit: 255
    t.string   "delivery_set_up?",                     limit: 255
    t.text     "special_delivery_instructions"
    t.integer  "delivery_charge_accrued"
    t.integer  "delivery_charge_paid"
    t.string   "stripe_customer_id",                   limit: 255
    t.string   "stripe_subscription_id",               limit: 255
    t.string   "email",                                limit: 255
    t.string   "raw_green_input",                      limit: 255
    t.string   "referral_code",                        limit: 255
    t.string   "monday_pickup_hub",                    limit: 255
    t.string   "thursday_pickup_hub",                  limit: 255
    t.string   "monday_delivery_hub",                  limit: 255
    t.string   "thursday_delivery_hub",                limit: 255
    t.string   "interval",                             limit: 255
    t.integer  "interval_count"
    t.boolean  "sponsored"
    t.string   "matched_referrers_code",               limit: 255
    t.boolean  "no_beef"
    t.boolean  "no_pork"
    t.boolean  "no_poultry"
    t.string   "delivery_boundary"
    t.boolean  "extra_ice"
    t.boolean  "different_delivery_address"
    t.string   "split_delivery_with"
    t.boolean  "price_increase_2015"
    t.string   "unit_number"
    t.boolean  "corporate"
    t.string   "corporate_office"
    t.boolean  "monday_delivery_enabled"
    t.boolean  "thursday_delivery_enabled"
    t.string   "social_media_handles"
    t.integer  "photos_submitted"
    t.integer  "meals_earned_from_photo_submission"
  end

  create_table "daily_snapshots", force: :cascade do |t|
    t.date     "date"
    t.integer  "active_customers_including_pause"
    t.integer  "active_customers_excluding_pause"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "total_meals"
    t.integer  "next_week_total"
    t.float    "active_customer_life_in_days"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "failed_invoice_trackers", force: :cascade do |t|
    t.string  "invoice_number",      limit: 255
    t.date    "invoice_date"
    t.integer "number_of_attempts"
    t.date    "latest_attempt_date"
    t.date    "next_attempt"
  end

  create_table "failed_invoices", force: :cascade do |t|
    t.string   "invoice_number",      limit: 255
    t.date     "invoice_date"
    t.integer  "number_of_attempts"
    t.date     "latest_attempt_date"
    t.date     "next_attempt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "stripe_customer_id",  limit: 255
    t.integer  "invoice_amount"
    t.boolean  "paid",                            default: false
    t.date     "date_paid"
    t.boolean  "closed"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string   "stripe_customer_id", limit: 255
    t.text     "feedback"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "occasion",           limit: 255
  end

  create_table "gift_redemptions", force: :cascade do |t|
    t.integer  "gift_id"
    t.string   "stripe_customer_id"
    t.integer  "amount_redeemed"
    t.integer  "amount_remaining"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  create_table "gift_remains", force: :cascade do |t|
    t.integer  "gift_id"
    t.integer  "amount_remaining"
    t.date     "date_to_process"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "stripe_customer_id"
  end

  create_table "gifts", force: :cascade do |t|
    t.string   "sender_stripe_customer_id"
    t.string   "sender_name"
    t.string   "sender_email"
    t.string   "recipient_name"
    t.string   "recipient_email"
    t.string   "charge_id"
    t.integer  "original_gift_amount"
    t.integer  "remaining_gift_amount"
    t.boolean  "pay_delivery"
    t.string   "gift_code"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.text     "personal_message"
  end

  create_table "meal_selections", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.date     "production_day"
    t.integer  "pork"
    t.integer  "beef"
    t.integer  "poultry"
    t.integer  "green_1"
    t.integer  "green_2"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.integer  "salad_bowl_1"
    t.integer  "salad_bowl_2"
    t.integer  "diet"
    t.integer  "chefs_special"
  end

  create_table "meal_statistics", force: :cascade do |t|
    t.string   "statistic"
    t.string   "statistic_type"
    t.integer  "value_integer"
    t.string   "value_string"
    t.text     "value_long_text"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  create_table "menu_ratings", force: :cascade do |t|
    t.integer  "menu_id"
    t.string   "stripe_customer_id"
    t.integer  "rating"
    t.text     "comment"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  create_table "menus", force: :cascade do |t|
    t.date     "production_day"
    t.string   "meal_name"
    t.string   "protein"
    t.string   "carb"
    t.string   "veggie"
    t.string   "extra"
    t.text     "notes"
    t.boolean  "dish"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "meal_type"
    t.float    "average_score"
    t.integer  "number_of_scores"
    t.string   "meal_count"
    t.boolean  "no_microwave"
  end

  create_table "no_email_customers", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  create_table "nutritional_infos", force: :cascade do |t|
    t.integer  "menu_id"
    t.string   "protein"
    t.string   "carb"
    t.string   "fat"
    t.string   "calories"
    t.string   "allergen"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "fiber"
    t.boolean  "spicy"
  end

  create_table "partner_product_delivery_dates", force: :cascade do |t|
    t.date     "delivery_date"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "partner_product_order_summaries", force: :cascade do |t|
    t.integer  "product_id"
    t.date     "delivery_date"
    t.integer  "ordered_quantity"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "partner_product_sale_details", force: :cascade do |t|
    t.integer  "partner_product_sale_id"
    t.integer  "partner_product_id"
    t.integer  "quantity"
    t.integer  "cost_in_cents"
    t.integer  "sale_price_before_hst_in_cents"
    t.integer  "total_discounts_in_cents"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "partner_product_sale_refunds", force: :cascade do |t|
    t.string   "stripe_refund_id"
    t.integer  "partner_product_sale_id"
    t.integer  "partner_product_sale_detail_id"
    t.integer  "amount_refunded"
    t.string   "refund_reason"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "refund_type"
  end

  create_table "partner_product_sales", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.date     "delivery_week"
    t.string   "order_status"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.integer  "total_amount_including_hst_in_cents"
    t.string   "sale_id"
    t.date     "delivery_date"
    t.string   "stripe_charge_id",                    default: [],              array: true
  end

  create_table "partner_products", force: :cascade do |t|
    t.integer  "vendor_id"
    t.integer  "product_id"
    t.string   "product_name"
    t.text     "product_description"
    t.string   "product_size"
    t.string   "vendor_product_sku"
    t.string   "vendor_product_upc"
    t.integer  "cost_in_cents"
    t.integer  "suggested_retail_price_in_cents"
    t.integer  "price_in_cents"
    t.string   "url_of_photo"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.boolean  "available"
    t.integer  "max_quantity"
    t.integer  "quantity_available"
    t.string   "photos",                          default: [],              array: true
    t.integer  "position"
  end

  create_table "photo_submissions", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.string   "caption"
    t.boolean  "selected"
    t.string   "photo"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.boolean  "paid"
    t.date     "date_selected"
    t.boolean  "photo_processing",   default: false, null: false
  end

  create_table "promotion_redemptions", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.integer  "promotion_id"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  create_table "promotions", force: :cascade do |t|
    t.date     "start_date"
    t.date     "end_date"
    t.string   "code",              limit: 255
    t.string   "stripe_coupon_id",  limit: 255
    t.boolean  "immediate_refund"
    t.boolean  "active"
    t.integer  "redemptions"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "amount_in_cents"
    t.boolean  "pause"
    t.boolean  "new_customer_only"
  end

  create_table "refunds", force: :cascade do |t|
    t.string   "stripe_customer_id", limit: 255
    t.date     "refund_week"
    t.date     "charge_week"
    t.string   "charge_id",          limit: 255
    t.integer  "amount_refunded"
    t.integer  "meals_refunded"
    t.string   "refund_reason",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "stripe_refund_id",   limit: 255
    t.integer  "internal_refund_id"
  end

  create_table "reminder_email_logs", force: :cascade do |t|
    t.string   "stripe_customer_id"
    t.date     "date_reminder_sent"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "discount"
    t.boolean  "restarted_with_direct_link"
    t.boolean  "restarted_without_direct_link"
    t.boolean  "requested_to_no_further_email"
  end

  create_table "scheduled_tasks", force: :cascade do |t|
    t.string   "task_name",           limit: 255
    t.integer  "day_of_week"
    t.integer  "hour_of_day"
    t.datetime "last_successful_run"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "parameter_1",         limit: 255
    t.string   "parameter_1_type",    limit: 255
    t.string   "parameter_2",         limit: 255
    t.string   "parameter_2_type",    limit: 255
    t.string   "parameter_3",         limit: 255
    t.string   "parameter_3_type",    limit: 255
    t.datetime "last_attempt_date"
  end

  create_table "shortened_urls", force: :cascade do |t|
    t.integer  "owner_id"
    t.string   "owner_type", limit: 20
    t.string   "url",                               null: false
    t.string   "unique_key", limit: 10,             null: false
    t.integer  "use_count",             default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "shortened_urls", ["owner_id", "owner_type"], name: "index_shortened_urls_on_owner_id_and_owner_type", using: :btree
  add_index "shortened_urls", ["unique_key"], name: "index_shortened_urls_on_unique_key", unique: true, using: :btree
  add_index "shortened_urls", ["url"], name: "index_shortened_urls_on_url", using: :btree

  create_table "start_date_tables", force: :cascade do |t|
  end

  create_table "start_dates", force: :cascade do |t|
    t.datetime "start_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stop_queue_records", force: :cascade do |t|
    t.date     "associated_cutoff"
    t.string   "stop_type",          limit: 255
    t.string   "stripe_customer_id", limit: 255
    t.date     "end_date"
    t.date     "start_date"
    t.integer  "updated_meals"
    t.integer  "updated_reg_mon"
    t.integer  "updated_reg_thu"
    t.integer  "updated_grn_mon"
    t.integer  "updated_grn_thu"
    t.string   "cancel_reason",      limit: 255
    t.datetime "queue_created_at"
    t.datetime "queue_updated_at"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "stop_queues", force: :cascade do |t|
    t.date     "associated_cutoff"
    t.string   "stop_type",          limit: 255
    t.string   "stripe_customer_id", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "end_date"
    t.date     "start_date"
    t.integer  "updated_meals"
    t.integer  "updated_reg_mon"
    t.integer  "updated_reg_thu"
    t.integer  "updated_grn_mon"
    t.integer  "updated_grn_thu"
    t.string   "cancel_reason",      limit: 255
  end

  create_table "stop_requests", force: :cascade do |t|
    t.string   "stripe_customer_id", limit: 255
    t.string   "request_type",       limit: 255
    t.date     "start_date"
    t.date     "end_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "cancel_reason",      limit: 255
    t.datetime "requested_date"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer  "weekly_meals"
    t.string   "stripe_plan_id", limit: 255
    t.string   "interval",       limit: 255
    t.integer  "interval_count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "price"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string   "setting",           limit: 255
    t.string   "setting_attribute", limit: 255
    t.text     "setting_value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "expiry_date"
  end

  create_table "user_activities", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "activity_type"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                           limit: 255
    t.string   "crypted_password",                limit: 255
    t.string   "salt",                            limit: 255
    t.string   "stripe_customer_id",              limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "reset_password_token",            limit: 255
    t.datetime "reset_password_token_expires_at"
    t.datetime "reset_password_email_sent_at"
    t.string   "facebook_email",                  limit: 255
    t.string   "role",                            limit: 255
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", using: :btree

  create_table "vendors", force: :cascade do |t|
    t.string   "ext_vendor_id"
    t.string   "vendor_name"
    t.text     "vendor_description"
    t.string   "contact_name"
    t.string   "phone_number"
    t.string   "email_address"
    t.string   "alt_contact_name"
    t.string   "alt_phone_number"
    t.string   "alt_email_address"
    t.string   "vendor_address"
    t.string   "alt_vendor_address"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

end
