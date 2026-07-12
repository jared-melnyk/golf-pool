Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#index"
  get "rules", to: "landing#rules", as: :rules

  get "signup", to: "users#new", as: :signup
  post "signup", to: "users#create"
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Trip simulator one-click login (local / TRIP_SIM_LOGIN=1 only; controller 404s otherwise)
  get "dev/trip_sim_login", to: "dev_sessions#create", as: :dev_trip_sim_login

  get "forgot_password", to: "password_resets#new", as: :forgot_password
  post "forgot_password", to: "password_resets#create"
  get "password_reset/:token", to: "password_resets#edit", as: :edit_password_reset
  patch "password_reset/:token", to: "password_resets#update", as: :password_reset

  namespace :admin do
    resources :games, only: [ :index ]
    resources :users, only: [ :index, :new, :create, :edit, :update ]
    resources :events, param: :token, only: [ :index, :show ] do
      resources :event_memberships, only: [ :create ]
    end
  end

  resources :tournaments, only: [ :index, :show ]

  resource :profile, only: [ :edit, :update ]

  resources :games, param: :token do
    collection do
      get :search_courses
      get :select_course
    end
    post :join, on: :member
    resource :setup, only: [ :show, :update ], controller: "game_setups" do
      get :search_courses
      get :select_course
    end
    member do
      get :edit_teams
      patch :update_teams
      patch :complete
      patch :reopen
    end
    resources :game_memberships, only: [ :destroy, :update ]
    resources :game_guests, only: [ :create, :destroy ]
    resources :hole_scores, only: [ :update ]
  end

  resources :events, param: :token do
    post :join, on: :member
    resource :standings, only: [ :show ], controller: "events/standings"
    resources :event_memberships, only: [ :destroy, :update ]
    resources :rounds, only: [ :new, :create, :edit, :update, :destroy ] do
      collection do
        get :search_courses
        get :select_course
      end
      resources :games, only: [ :new, :create ]
    end
  end

  # Legacy bookmarks: /events/:event_token/games/:id → /games/:token
  get "/events/:event_token/games/:id",
      to: redirect { |params, _|
        game = Game.find(params[:id])
        "/games/#{game.token}"
      },
      constraints: { id: /\d+/ }

  get "/events/:event_token/games/:id/edit_teams",
      to: redirect { |params, _|
        game = Game.find(params[:id])
        "/games/#{game.token}/edit_teams"
      },
      constraints: { id: /\d+/ }

  post "sync/tournament_results/:tournament_id", to: "sync#tournament_results", as: :sync_tournament_results
  post "sync/field", to: "sync#field", as: :sync_field

  resources :pools, param: :token do
    post "join", on: :member
    resources :pool_tournaments, only: [ :create, :destroy, :show ]
    resources :pool_users, only: [ :create, :destroy ], path: "members"
    resources :picks, only: [ :index, :new, :create, :edit, :update ]
  end
end
