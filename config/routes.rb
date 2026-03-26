Rails.application.routes.draw do
  root "home#index"

  # Auth
  get "/auth/github/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/sign_out", to: "sessions#destroy"

  # Username claim (new user onboarding)
  get "/claim-username", to: "usernames#new", as: :new_username
  post "/claim-username", to: "usernames#create"

  # Dashboard
  get "/dashboard", to: "dashboard#index"

  # Entries
  resources :entries, only: [ :create, :destroy ]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Public profiles — must be last
  get "/:username", to: "profiles#show", as: :profile, constraints: { username: /[a-zA-Z0-9_-]+/ }
end
