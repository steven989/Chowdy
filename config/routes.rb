Chowdy::Application.routes.draw do


  get "oauths/oauth"
  get "oauths/callback"
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  
  root to: 'user_sessions#new'
  post "user_sessions/create"
  get "user_sessions/destroy"
  get 'login' => 'user_sessions#new', :as => :login
  get 'logout' => 'user_sessions#destroy', :as => :logout

  post 'customers/create' => 'customers#create', as: 'create_customer'
  post 'customers/failed_invoice' => 'customers#fail', as: 'failed_invoice'
  post 'customers/payment' => 'customers#payment', as: 'payment'
  post 'customers/submit_meal_rating' => 'customers#rate_menu_item', as: 'submit_meal_rating'
  post 'customers/update/:id' => 'customers#update', as: 'update_customer'
  get 'customers/:id/create_profile' => 'customers#create_profile', as: 'create_customer_profile'
  get 'customers/:id/resend_confirmation_email_form' => 'customers#resend_confirmation_email_form', as: 'resend_confirmation_email_form'
  get 'customers/:id/resend_sign_up_link_form' => 'customers#resend_sign_up_link_form', as: 'resend_sign_up_link_form'
  get 'customers/:id/olrestart' => 'customers#one_link_restart', as: 'one_link_restart'
  get 'customers/:id/add_to_do_not_email' => 'customers#add_to_do_not_email', as: 'add_to_do_not_email'
  post 'customers/:id/resend_sign_up_link' => 'customers#resend_sign_up_link', as: 'resend_sign_up_link'
  post 'customers/:id/resend_signup_confirmation_email' => 'customers#resend_signup_confirmation_email', as: 'resend_signup_confirmation_email'
  get 'customers/resend_sign_up_link' => 'customers#resend_sign_up_link_customer_request', as: 'resend_sign_up_link_customer_request'
  resources :users, only: [:show, :new, :create, :edit, :update, :destroy]
  get 'user/profile' => 'users#profile', as: 'user_profile'
  get 'admin_action/customer_sheet' => 'admin_actions#customer_sheet', as: 'customer_sheet'
  get 'admin_action/deliveries_csv' => 'admin_actions#delivery_csv', as: 'deliveries_csv'
  get 'admin_action/next_week_breakdown' => 'admin_actions#next_week_breakdown', as: 'next_week_breakdown'
  get 'admin_action/customer/:id/edit' => 'admin_actions#individual_customer_edit', as: 'admin_edit_customer'
  put 'admin_action/customer/:id/update' => 'admin_actions#individual_customer_update', as: 'admin_update_customer'
  get 'admin_action/failed_invoice/:id/mark_as_paid' => 'admin_actions#mark_failed_invoice_as_paid', as: 'mark_failed_invoice_as_paid'
  get 'admin_action/impersonate_user/:id' => 'admin_actions#impersonate', as: 'impersonate_user'
  get 'admin_action/get_user_activity/:id' => 'admin_actions#get_user_activity', as: 'get_user_activity'
  post 'admin_action/search_customer' => 'admin_actions#search_customer', as: 'search_customer'
  
  get  'partner_product_sales/weekly_sales_total_report' => 'partner_product_sales#weekly_sales_total_report', as: 'weekly_marketplace_totals'
  get  'partner_product_sales/weekly_sales_report' => 'partner_product_sales#weekly_sales_report', as: 'weekly_marketplace_deliveries'
  post 'partner_product_sales/search_order_by_customer' => 'partner_product_sales#search_order_by_customer', as: 'search_order_by_customer'
  post 'partner_product_sales/search_order_details_by_id' => 'partner_product_sales#search_order_details_by_id', as: 'search_order_details_by_id'
  get 'partner_product_sales/view_orders' => 'partner_product_sales#view_orders', as: 'view_orders'
  get 'partner_product_sales/edit_order' => 'partner_product_sales#edit_order', as: 'edit_order'
  put 'partner_product_sales/update_order' => 'partner_product_sales#update_order', as: 'update_order'
  get 'partner_product_sales/cancel_order' => 'partner_product_sales#cancel_order', as: 'cancel_order'
  get 'partner_product_sales/intro' => 'partner_product_sales#intro', as: 'marketplace_intro'
  put 'partner_product_sales/update_delivery_date' => 'partner_product_sales#update_delivery_date', as: 'update_order_delivery_date'
  put 'partner_product_sales/refund' => 'partner_product_sales#refund', as: 'order_refund'

  
  

  post 'partner_product_sales/order' => 'partner_product_sales#order', as: 'order_partner_product'

  post 'meal_selection/update' => 'meal_selections#update', as:'update_meal_choice'
  get  'meal_selections/view' => 'meal_selections#view_selection', as:'view_meals_selection'

  resources :password_resets
  resources :system_settings
  resources :vendors
  resources :partner_products
  get  'partner_product/paginate' => 'partner_products#paginate', as:'paginate_partner_products'
  get  'partner_product/:id/remove_photos' => 'partner_products#remove_photos', as:'remove_partner_product_photos'

  resources :scheduled_tasks
  resources :menus, only: [:update, :show]
  get 'menu/:id/pull_rating_details' => 'menus#pull_rating_details', as: 'pull_rating_details'
  get 'menu/pull_suggestion' => 'menus#pull_suggestion', as: 'pull_suggestion'
  get 'menu/pull_individual_detail' => 'menus#pull_individual_detail', as: 'pull_individual_detail'
  get 'menu/:id/edit_nutritional_info' => 'menus#edit_nutritional_info', as: 'edit_nutritional_info'
  post 'menu/:id/update_nutritional_info' => 'menus#update_nutritional_info', as: 'update_nutritional_info'
  post 'menu/copied_menu_nutritional_update' => 'menus#copied_menu_nutritional_update', as: 'copied_menu_nutritional_update'
  get 'scheduled_task/:id/run' => 'scheduled_tasks#run', as: 'run_task'

  get 'announcement/new' => 'system_settings#new_announcement', as: 'new_announcement'
  post 'announcement/create' => 'system_settings#create_announcement', as: 'create_announcement'
  resources :promotions
  put 'promotions/:id/activate' => 'promotions#activate', as: 'activate_promotion'

  post "oauth/callback" => "oauths#callback"
  get "oauth/callback" => "oauths#callback" # for use with Github, Facebook
  get "oauth/:provider" => "oauths#oauth", :as => :auth_at_provider

  get 'start_date/edit' => 'start_dates#edit', as: 'edit_start_date'
  put 'start_date/update' => 'start_dates#update', as: 'update_start_date'

  get 'partner_product_delivery_dates/edit' => 'partner_product_delivery_dates#edit', as: 'edit_partner_product_delivery_date'
  put 'partner_product_delivery_dates/update' => 'partner_product_delivery_dates#update', as: 'update_partner_product_delivery_date'

  post 'redeem_promo' => 'promotion_redemptions#redeem', as: 'redeem_promo'

  get 'gifts/:id/view_redemption' => 'gifts#view_redemption', as: 'view_redemption'
  get 'gifts/:id/resend_sender_confirmation_form' => 'gifts#resend_sender_confirmation_form', as: 'resend_sender_confirmation_form'
  get 'gifts/:id/resend_recipient_confirmation_form' => 'gifts#resend_recipient_confirmation_form', as: 'resend_recipient_confirmation_form'
  post 'gifts/:id/resend_sender_confirmation' => 'gifts#resend_sender_confirmation', as: 'resend_sender_confirmation'
  post 'gifts/:id/resend_recipient_confirmation' => 'gifts#resend_recipient_confirmation', as: 'resend_recipient_confirmation'

  match '/:id' => "shortener/shortened_urls#show", via: [:get]

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
