Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#index"
  get "rules", to: "landing#rules", as: :rules

  get "signup", to: "users#new", as: :signup
  post "signup", to: "users#create"
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get "forgot_password", to: "password_resets#new", as: :forgot_password
  post "forgot_password", to: "password_resets#create"
  get "password_reset/:token", to: "password_resets#edit", as: :edit_password_reset
  patch "password_reset/:token", to: "password_resets#update", as: :password_reset

  resources :tournaments, only: [ :index, :show ]

  post "sync/tournament_results/:tournament_id", to: "sync#tournament_results", as: :sync_tournament_results
  post "sync/field", to: "sync#field", as: :sync_field

  resources :pools, param: :token do
    post "join", on: :member
    resources :pool_tournaments, only: [ :create, :destroy ]
    resources :pool_users, only: [ :create, :destroy ], path: "members"
    resources :picks, only: [ :index, :new, :create, :edit, :update ]
  end
end
