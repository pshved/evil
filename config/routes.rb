Zlo::Application.routes.draw do
  get "api/commit_activity"
  get "api/commit_clicks"

  root :controller => 'backwards', :action => 'index'

  match 'login' => 'user_sessions#new', :as => 'login'
  match 'logout' => 'user_sessions#destroy', :as => 'logout'

  resources :threads, :only => [:new]
  resources :user_sessions
  resources :users
  resources :posts, :path => 'p' do
    member do
      get :toggle_showhide, :remove
    end
    collection do
      get :latest
      match 'latest/:number' => 'posts#latest'
    end
  end
  resources :private_messages, :path => 'persmsg'

  resources :loginposts, :only => [:create]

  # User's view settings
  resources :presentations do
    member do
      get :use, :clone, :make_default
    end
    collection do
      get :edit_local
      get :edit_default
    end
  end

  namespace :admin do
    # Configurable_engine is already included here via its own routes
    get 'index' => 'specials#index'
  end

  resources :moderation_actions, :path => 'moder'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
