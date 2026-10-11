# What the GitHub repos section of Settings shows. Settings renders it with the
# page, and GithubReposController#index renders it again into its frame after
# checking GitHub, so both read the same things.
module GithubReposSection
  extend ActiveSupport::Concern

  private

  def github_repos_section
    {
      github_repos: current_user.github_repos.order(:name),
      last_github_sync: current_user.last_synced_at(source: :github),
      github_app: GithubAppGateway.configured?,
      repo_scope: User.scopes_include_repo?(current_user.github_token_scopes)
    }
  end
end
