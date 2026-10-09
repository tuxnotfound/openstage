# The Openstage GitHub App (C12), registered for one example with a throwaway key.
GITHUB_APP_TEST_KEY = OpenSSL::PKey::RSA.new(2048)

RSpec.shared_context "with the GitHub App configured" do
  around do |example|
    settings = Rails.configuration.x.github_app
    saved = settings.to_h
    settings.merge!(slug: "openstage-test", client_id: "Iv23test", client_secret: "app-secret",
                    private_key: GITHUB_APP_TEST_KEY.to_pem)
    example.run
  ensure
    settings.clear
    settings.merge!(saved)
  end
end
