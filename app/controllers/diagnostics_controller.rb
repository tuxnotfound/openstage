class DiagnosticsController < ApplicationController
  before_action :require_owner

  def show
    render plain: [
      "env:             #{Rails.env}",
      "commit:          #{ENV.fetch('RENDER_GIT_COMMIT', 'unknown')}",
      "applied_version: #{applied_versions.last || 'none'}",
      "repo_version:    #{repo_versions.last || 'none'}",
      "pending:         #{(repo_versions - applied_versions).presence&.join(', ') || 'none'}",
      "users.email:     #{User.column_names.include?('email')}",
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
end
