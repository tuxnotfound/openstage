Rails.application.routes.draw do
  root "home#index"

  # Auth
  get "/auth/github/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "/sign_out", to: "sessions#destroy"

  # Read-only private repos through the Openstage GitHub App (C12). The
  # callback is the App's Setup URL on GitHub.
  get "/github_app/install", to: "github_installations#new", as: :new_github_installation
  get "/github_app/callback", to: "github_installations#create", as: :github_installation_callback

  # Username claim (new user onboarding)
  get "/claim-username", to: "usernames#new", as: :new_username
  post "/claim-username", to: "usernames#create"

  # Dashboard
  get "/dashboard", to: "dashboard#index"

  # Owner-only deploy/migration diagnostics
  get "/_deploy_check", to: "diagnostics#show"

  # The revamp's components in light and dark, to build screens against.
  get "/_kit", to: "kit#show", as: :kit unless Rails.env.production?

  # Owner-only funnel metrics; the gates are scored off this
  get "/admin", to: "admin#show", as: :admin
  post "/admin/test_email", to: "admin#test_email", as: :admin_test_email
  post "/admin/test_weekly_email", to: "admin#test_weekly_email", as: :admin_test_weekly_email

  # The week card and the recap picker are gone; their links in weekly emails
  # already sent open the dashboard.
  get "/week(/*rest)", to: redirect("/dashboard")
  get "/recap", to: redirect("/dashboard")

  # Analytics (Pro)
  get "/analytics", to: "analytics#index", as: :analytics

  # What the pages' chart scripts ask for when a view changes, as JSON. "api"
  # is a reserved username, so no builder or project collides with these.
  namespace :api, defaults: { format: :json } do
    get "progress/:username", to: "progress#show", as: :progress, constraints: { username: /[a-zA-Z0-9_-]+/ }
    get "analytics", to: "analytics#show", as: :analytics
  end

  # Sync triggers
  post "/sync/github", to: "syncs#github", as: :sync_github

  # A project's words, website and picture, edited in its dashboard row.
  resources :projects, only: [ :edit, :update ]

  # Repo management. index is the Settings frame that checks GitHub first.
  resources :github_repos, only: [ :index, :update ]

  # Entries
  resources :entries, only: [ :create, :edit, :update, :destroy ] do
    # The progress section's tag panel, for any entry type.
    resource :project, only: :update, module: :entries
  end

  # Checkout / Billing
  post "/checkout", to: "checkouts#create", as: :checkout
  get "/billing", to: "checkouts#billing_portal", as: :billing_portal

  # Stripe webhook
  post "/webhooks/stripe", to: "webhooks#stripe", as: :stripe_webhook

  # GitHub App webhooks (C12): installs, uninstalls and repo picks on GitHub
  post "/webhooks/github", to: "github_webhooks#create", as: :github_webhook

  # Email subscribe on public profiles (C11). Token routes sit above the
  # profile catch-all; "subscriptions" is a reserved username.
  post "/:username/subscribe", to: "subscriptions#create", as: :profile_subscribe, constraints: { username: /[a-zA-Z0-9_-]+/ }
  get "/subscriptions/:token/confirm", to: "subscriptions#confirm", as: :confirm_subscription
  # Mail scanners open every link in a mail, so a GET only asks; the POST
  # (the page's button, or a client's RFC 8058 one-click) unsubscribes.
  get "/subscriptions/:token/unsubscribe", to: "subscriptions#confirm_unsubscribe", as: :unsubscribe_subscription
  post "/subscriptions/:token/unsubscribe", to: "subscriptions#unsubscribe"

  # The stop link in the builder's weekly email (F2), same two steps
  get "/weekly_email/unsubscribe", to: "weekly_emails#confirm_unsubscribe", as: :weekly_email_unsubscribe
  post "/weekly_email/unsubscribe", to: "weekly_emails#unsubscribe"

  # Global feed
  get "/feed", to: "feed#index", as: :feed

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

  # Marketing / content pages
  get "/about", to: "pages#about", as: :about
  get "/pricing", to: "pages#pricing", as: :pricing
  get "/blog", to: "blog#index", as: :blog
  get "/blog/:slug", to: "blog#show", as: :blog_post

  # SEO
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  # The card a shared link shows. "blog" is a reserved username, so a post's
  # card never meets a builder's.
  get "/og", to: "og_images#site", as: :og_site
  get "/og/blog/:slug", to: "og_images#post", as: :og_post
  get "/og/:username", to: "og_images#builder", as: :og_builder
  get "/og/:username/:project", to: "og_images#project", as: :og_project, format: false,
      constraints: { username: /[a-zA-Z0-9_-]+/, project: /[a-zA-Z0-9._-]+/ }
  get "/badge/:username", to: "badges#show", as: :profile_badge, defaults: { format: :svg }
  get "/embed/:username/preview", to: "embeds#preview", as: :profile_embed_preview
  get "/embed/:username.js", to: "embeds#show", as: :profile_embed, defaults: { format: :js }
  get "/e/:id/out", to: "entry_clicks#show", as: :entry_click_out

  # GEO — structured summary for LLMs / AI search engines (llmstxt.org)
  get "/llms.txt", to: "llms#show", as: :llms, defaults: { format: :text }

  # A project page's Visit and View on GitHub buttons, counted on the way out.
  get "/:username/:project/:to", to: "project_clicks#show", as: :project_click_out, format: false,
      constraints: { username: /[a-zA-Z0-9_-]+/, project: /[a-zA-Z0-9._-]+/, to: /visit|github/ }

  # A project's page: the repo's name without its owner. format: false, as
  # repo names may hold a dot.
  get "/:username/:project", to: "project_pages#show", as: :project_page, format: false,
      constraints: { username: /[a-zA-Z0-9_-]+/, project: /[a-zA-Z0-9._-]+/ }

  # Public profiles — must be last
  get "/:username", to: "profiles#show", as: :profile, constraints: { username: /[a-zA-Z0-9_-]+/ }
end
