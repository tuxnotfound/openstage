class DiagnosticsController < ApplicationController
  before_action :require_owner

  SAFE_URL_SQL = "^https?://".freeze

  def show
    render plain: [
      "env:             #{Rails.env}",
      "commit:          #{ENV.fetch('RENDER_GIT_COMMIT', 'unknown')}",
      "applied_version: #{applied_versions.last || 'none'}",
      "repo_version:    #{repo_versions.last || 'none'}",
      "pending:         #{(repo_versions - applied_versions).presence&.join(', ') || 'none'}",
      "users.email:     #{User.column_names.include?('email')}",
      "owner_uid_set:   #{ENV['OWNER_GITHUB_UID'].present?}",
      "unsafe_websites: #{format_list(unsafe_website_urls)}",
      "unsafe_entries:  #{unsafe_entry_urls}",
      "checked_at:      #{Time.current.iso8601}"
    ].join("\n")
  end

  private

  # 404 rather than a redirect so the route is invisible to anyone but the owner.
  def require_owner
    head :not_found unless current_user&.owner?
  end

  def applied_versions
    ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations").sort
  end

  def repo_versions
    Dir[Rails.root.join("db/migrate/*.rb")].filter_map { |path| File.basename(path)[/\A\d+/] }.sort
  end

  # Rows written before the scheme validation existed. The render sites are
  # already defended, so anything here is cleanup, not live exposure.
  def unsafe_website_urls
    User.where.not(website_url: [ nil, "" ])
        .where.not("website_url ~* ?", SAFE_URL_SQL)
        .pluck(:username, :website_url)
        .map { |username, url| "#{username}=#{url.truncate(40)}" }
  end

  def unsafe_entry_urls
    Entry.where.not(url: [ nil, "" ])
         .where.not("url ~* ?", SAFE_URL_SQL)
         .count
  end

  def format_list(values)
    values.any? ? "#{values.size} (#{values.join(', ')})" : "none"
  end
end
