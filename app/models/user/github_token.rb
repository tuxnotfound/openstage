class User
  # The builder's GitHub token: which one to keep at sign-in, and what it lets
  # Openstage read.
  module GithubToken
    extend ActiveSupport::Concern

    class_methods do
      def scopes_include_repo?(scopes)
        scopes.to_s.split(",").map(&:strip).include?("repo")
      end
    end

    # GitHub issues each token with the scopes of that sign-in request, not of
    # the whole grant. Since C10 a plain sign-in asks only for user:email, so
    # storing its token blindly drops the private-repo access the user gave
    # through the older repo-scope step in Settings. Keep the broader token,
    # until the GitHub App (C12) reads their private repos instead.
    def adopt_github_token(token, scopes)
      return if token.blank?
      return if !github_installation_id? && private_repo_access? && !self.class.scopes_include_repo?(scopes)

      self.github_access_token = token
      self.github_token_scopes = scopes.presence
    end

    # Through the GitHub App (C12), or through the older repo-scoped token.
    def private_repo_access?
      github_installation_id? || self.class.scopes_include_repo?(github_token_scopes)
    end

    # True right after a save that turned the repo scope on.
    def gained_private_repo_access?
      self.class.scopes_include_repo?(github_token_scopes) && !self.class.scopes_include_repo?(github_token_scopes_before_last_save)
    end
  end
end
