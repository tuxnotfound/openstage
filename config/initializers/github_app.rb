# The Openstage GitHub App (C12): read-only Contents and Metadata on the private
# repos each builder picks. Unset wherever the App is not registered, and
# Settings then keeps the older step that asks for the repo scope.
github_app = Rails.application.config.x.github_app
github_app.slug        = ENV["GITHUB_APP_SLUG"].presence
github_app.client_id   = ENV["GITHUB_APP_CLIENT_ID"].presence
# Render kept a pasted PEM's newlines. On tux-box the key is one line in .env.kamal, and Kamal
# writes it into the container's env file with every backslash doubled, so each newline arrives
# as \\n. Any run of backslashes before an n is a newline; a PEM never holds a backslash.
github_app.private_key = ENV["GITHUB_APP_PRIVATE_KEY"].presence&.gsub(/\\+n/, "\n")
# Signs GitHub's webhooks; GithubWebhooksController answers 404 without it.
github_app.webhook_secret = ENV["GITHUB_APP_WEBHOOK_SECRET"].presence
