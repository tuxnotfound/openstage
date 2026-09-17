class AddGithubTokenScopesToUsers < ActiveRecord::Migration[7.1]
  def change
    # Scopes GitHub granted with the stored token, as returned in the token
    # response. Since C10 sign-in requests only user:email, and GitHub issues
    # each token with the scopes of that request, so this is the only way to
    # know whether private repos can be listed at all.
    add_column :users, :github_token_scopes, :string
  end
end
