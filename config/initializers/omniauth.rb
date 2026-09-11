# oauth2 gem 2.0+ adds response_type=code to the authorize URL.
# GitHub returns 404 for newer OAuth Apps (Ov-prefixed client IDs) when
# response_type=code is present. Remove it at the source.
module OAuth2
  module Strategy
    class AuthCode
      def authorize_params(params = {})
        params.merge("client_id" => @client.id)
      end
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github, ENV.fetch("GITHUB_CLIENT_ID", nil), ENV.fetch("GITHUB_CLIENT_SECRET", nil),
           # A public proof-of-work page needs no access to private repositories.
           # Requesting "repo" asked for read AND write on every private repo,
           # which is both a privacy hazard and the kind of thing a Show HN
           # thread leads with. Public repos need no scope at all.
           scope: "user:email",
           client_options: {
             auth_scheme: :request_body
           }
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

if Rails.env.development?
  OmniAuth.config.allowed_request_methods = [ :post, :get ]
end
