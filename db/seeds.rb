# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


Subscription.create(weekly_meals: 6, stripe_plan_id: "6mealswk",interval:"week",interval_count:1)
Subscription.create(weekly_meals: 8, stripe_plan_id: "8mealswk",interval:"week",interval_count:1)
Subscription.create(weekly_meals: 10, stripe_plan_id: "10mealswk",interval:"week",interval_count:1)
Subscription.create(weekly_meals: 12, stripe_plan_id: "12mealswk",interval:"week",interval_count:1)
Subscription.create(weekly_meals: 14, stripe_plan_id: "14mealswk",interval:"week",interval_count:1)

