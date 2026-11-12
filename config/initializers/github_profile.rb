# Openstage's own GitHub token, for the stage a visitor previews before
# signing in (GithubProfileGateway). A token with no scope reads public data
# alone, which is all a preview shows. Previews are off without it.
Rails.application.config.x.github_profile_token = ENV["GITHUB_PREVIEW_TOKEN"].presence
