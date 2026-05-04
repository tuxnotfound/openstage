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

  # Sync triggers
  post "/sync/github", to: "syncs#github", as: :sync_github

  # Repo management
  resources :github_repos, only: [ :update ]

  # Entries
  resources :entries, only: [ :create, :edit, :update, :destroy ]

  # Checkout / Billing
  post "/checkout", to: "checkouts#create", as: :checkout
  get "/billing", to: "checkouts#billing_portal", as: :billing_portal

  # Stripe webhook
  post "/webhooks/stripe", to: "webhooks#stripe", as: :stripe_webhook

  # Settings
  get "/settings", to: "settings#show",            as: :settings
  patch "/settings", to: "settings#update"
  patch "/settings/username", to: "settings#update_username", as: :settings_username
  delete "/settings", to: "settings#destroy"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Common scanner targets: return 404 without raising routing exceptions.
  match "/wp-admin/*path", to: ->(_env) { [ 404, { "Content-Type" => "text/plain" }, [ "Not Found" ] ] }, via: :all
  match "/xmlrpc.php", to: ->(_env) { [ 404, { "Content-Type" => "text/plain" }, [ "Not Found" ] ] }, via: :all

  # Some crawlers request favicon.png; avoid hitting profile lookup.
  get "/favicon.png", to: redirect("/favicon.ico", status: 301)

  # SEO
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "/og/:username", to: "og_images#show", as: :og_image
  get "/badge/:username", to: "badges#show", as: :profile_badge, defaults: { format: :svg }

  # Public profiles — must be last
  get "/:username", to: "profiles#show", as: :profile, constraints: { username: /[a-zA-Z0-9_-]+/ }
end
