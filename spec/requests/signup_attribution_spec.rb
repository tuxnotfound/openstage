require "rails_helper"

RSpec.describe "Signup attribution", type: :request do
  describe "first-touch ref capture" do
    it "remembers the first ref a visitor arrives with" do
      get "/", params: { ref: "recap" }
      expect(session[:signup_ref]).to eq("recap")

      # A later tagged link must not overwrite the first touch.
      get "/", params: { ref: "badge" }
      expect(session[:signup_ref]).to eq("recap")
    end

    it "records an unknown or missing ref as direct rather than dropping it" do
      expect(User.normalize_ref("not-a-real-source")).to eq("direct")
      expect(User.normalize_ref(nil)).to eq("direct")
      expect(User.normalize_ref("")).to eq("direct")
    end

    it "accepts every ref the product actually emits" do
      User::REFS.each { |ref| expect(User.normalize_ref(ref)).to eq(ref) }
    end

    it "attributes the X bio link separately from recap posts" do
      get "/", params: { ref: "bio" }
      expect(session[:signup_ref]).to eq("bio")
    end

    it "does not set a ref when none is given" do
      get "/"
      expect(session[:signup_ref]).to be_nil
    end
  end

  describe "email capture" do
    it "keeps the email GitHub returns at sign-in" do
      auth = OmniAuth::AuthHash.new(
        uid: "999", info: { nickname: "newbuilder", name: "New", email: "new@example.com", image: "http://img" },
        credentials: { token: "tok" }
      )

      user = User.from_github_omniauth(auth)
      expect(user.email).to eq("new@example.com")
    end

    it "does not blank an existing email when GitHub returns none" do
      existing = create(:user, github_uid: "555", email: "kept@example.com")
      auth = OmniAuth::AuthHash.new(
        uid: "555", info: { nickname: existing.github_username, name: "X", email: nil, image: "http://img" },
        credentials: { token: "tok" }
      )

      expect(User.from_github_omniauth(auth).email).to eq("kept@example.com")
    end
  end
end
