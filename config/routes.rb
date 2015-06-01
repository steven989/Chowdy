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
  post 'customers/update/:id' => 'customers#update', as: 'update_customer'
  get 'customers/:id/create_profile' => 'customers#create_profile', as: 'create_customer_profile'
  resources :users, only: [:show, :new, :create, :edit, :update, :destroy]
  get 'user/profile' => 'users#profile', as: 'user_profile'
  get 'admin_action/customer_sheet' => 'admin_actions#customer_sheet', as: 'customer_sheet'
  get 'admin_action/next_week_breakdown' => 'admin_actions#next_week_breakdown', as: 'next_week_breakdown'
  get 'admin_action/customer/:id/edit' => 'admin_actions#individual_customer_edit', as: 'admin_edit_customer'
  put 'admin_action/customer/:id/update' => 'admin_actions#individual_customer_update', as: 'admin_update_customer'

  resources :password_resets
  resources :system_settings
  resources :scheduled_tasks
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
