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

  # The week card: what the builder shipped, published and built, as a picture
  # to post. /week opens the current week.
  get "/week", to: "week_cards#show", as: :current_week_card
  get "/week/:week", to: "week_cards#show", as: :week_card, constraints: { week: /\d{4}-W\d{2}/ }
  patch "/week/:week", to: "week_cards#update", constraints: { week: /\d{4}-W\d{2}/ }
  get "/week/:week/preview", to: "week_cards#preview", as: :week_card_preview, constraints: { week: /\d{4}-W\d{2}/ }

  # The recap picker is gone; links in weekly emails already sent open the
  # week card instead, still counted as opened from the email.
  get "/recap", to: redirect { |_params, request| [ "/week", request.query_string.presence ].compact.join("?") }

  # What the cards report from the browser: downloads, copies, compose boxes.
  post "/events", to: "events#create", as: :events

  # Analytics (Pro)
  get "/analytics", to: "analytics#index", as: :analytics

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

  # The Make a card dialog on the builder's own page.
  get "/progress/card", to: "progress_cards#show", as: :progress_card

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
  get "/og/:username", to: "og_images#show", as: :og_image
  get "/badge/:username", to: "badges#show", as: :profile_badge, defaults: { format: :svg }
  get "/embed/:username/preview", to: "embeds#preview", as: :profile_embed_preview
  get "/embed/:username.js", to: "embeds#show", as: :profile_embed, defaults: { format: :js }
  get "/e/:id/out", to: "entry_clicks#show", as: :entry_click_out

  # GEO — structured summary for LLMs / AI search engines (llmstxt.org)
  get "/llms.txt", to: "llms#show", as: :llms, defaults: { format: :text }

  # Public profiles — must be last
  get "/:username", to: "profiles#show", as: :profile, constraints: { username: /[a-zA-Z0-9_-]+/ }
end
