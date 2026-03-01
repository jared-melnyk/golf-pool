Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#index"

  get "signup", to: "users#new", as: :signup
  post "signup", to: "users#create"
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resources :tournaments, only: [ :index, :new, :create, :show ] do
    resources :tournament_results, only: [ :create, :destroy ], path: "results"
  end
  resources :golfers, only: [ :index, :new, :create ]

  get "sync", to: "sync#index", as: :sync_index
  post "sync/tournaments", to: "sync#tournaments"
  post "sync/players", to: "sync#players"
  post "sync/tournament_results/:tournament_id", to: "sync#tournament_results", as: :sync_tournament_results
  post "sync/field", to: "sync#field", as: :sync_field

  resources :pools, param: :token do
    post "join", on: :member
    resources :pool_tournaments, only: [ :create, :destroy ]
    resources :pool_users, only: [ :create, :destroy ], path: "members"
    resources :picks, only: [ :index, :new, :create, :edit, :update ]
  end
end
