module GithubExtras
  # The token that reads a repo: the App's installation token for a private
  # repo picked there, else the builder's sign-in token. The installation token
  # is fetched once; it lasts an hour, longer than a refresh takes.
  class Tokens
    def initialize(user)
      @user = user
    end

    def for(repo)
      (repo&.private_repo? && installation_token) || @user.github_access_token
    end

    private

    def installation_token
      return @installation_token if defined?(@installation_token)

      installation_id = @user.github_installation_id
      @installation_token = (GithubAppGateway.installation_token(installation_id) if installation_id && GithubAppGateway.configured?)
    rescue ApplicationGateway::NotFound
      # Uninstalled since the last sync, which settles it there.
      @installation_token = nil
    end
  end
end
