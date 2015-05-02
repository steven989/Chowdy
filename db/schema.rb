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

ActiveRecord::Schema.define(version: 20150502223644) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "customers", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.string   "gender"
    t.string   "race"
    t.string   "phone_number"
    t.string   "hub"
    t.string   "hub_note"
    t.string   "purchase"
    t.string   "active?"
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
    t.string   "paused?"
    t.date     "pause_start_date"
    t.date     "pause_end_date"
    t.string   "openmat_member?"
    t.string   "one_time_fee_paid?"
    t.string   "referral"
    t.integer  "referral_bonus_referrer"
    t.integer  "referral_bonus_referree"
    t.integer  "referral_bonus_paid"
    t.date     "date_signed_up_for_recurring"
    t.date     "date_cancelled"
    t.string   "pause_cancel_request"
    t.string   "cancellation_reason"
    t.text     "notes"
    t.string   "meal_preferences"
    t.date     "last_surveyed"
    t.string   "recurring_delivery?"
    t.string   "delivery_address"
    t.string   "delivery_time"
    t.string   "delivery_set_up?"
    t.string   "special_delivery_instructions"
    t.integer  "delivery_charge_accrued"
    t.integer  "delivery_charge_paid"
    t.string   "stripe_customer_id"
    t.string   "stripe_subscription_id"
    t.string   "email"
    t.string   "raw_green_input"
  end

  create_table "failed_invoice_trackers", force: true do |t|
    t.string  "invoice_number"
    t.date    "invoice_date"
    t.integer "number_of_attempts"
    t.date    "latest_attempt_date"
    t.date    "next_attempt"
  end

  create_table "failed_invoices", force: true do |t|
    t.string   "invoice_number"
    t.date     "invoice_date"
    t.integer  "number_of_attempts"
    t.date     "latest_attempt_date"
    t.date     "next_attempt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "stripe_customer_id"
    t.integer  "invoice_amount"
    t.boolean  "paid",                default: false
    t.date     "date_paid"
  end

  create_table "feedbacks", force: true do |t|
    t.string   "stripe_customer_id"
    t.text     "feedback"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "start_date_tables", force: true do |t|
  end

  create_table "start_dates", force: true do |t|
    t.datetime "start_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stop_queues", force: true do |t|
    t.date     "associated_cutoff"
    t.string   "stop_type"
    t.string   "stripe_customer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "end_date"
    t.date     "start_date"
  end

  create_table "stop_requests", force: true do |t|
    t.string   "stripe_customer_id"
    t.string   "request_type"
    t.date     "start_date"
    t.date     "end_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "email",              null: false
    t.string   "crypted_password",   null: false
    t.string   "salt",               null: false
    t.string   "stripe_customer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree

end
