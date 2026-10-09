# The Openstage GitHub App (C12): read-only Contents and Metadata on the private
# repos each builder picks. Unset wherever the App is not registered, and
# Settings then keeps the older step that asks for the repo scope.
github_app = Rails.application.config.x.github_app
github_app.slug          = ENV["GITHUB_APP_SLUG"].presence
github_app.client_id     = ENV["GITHUB_APP_CLIENT_ID"].presence
github_app.client_secret = ENV["GITHUB_APP_CLIENT_SECRET"].presence
# Render keeps a pasted PEM's newlines; a one-line value with literal \n works too.
github_app.private_key   = ENV["GITHUB_APP_PRIVATE_KEY"].presence&.gsub("\\n", "\n")
