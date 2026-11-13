require "rails_helper"
require "support/github_profile"

RSpec.describe "Previews", type: :request do
  include GithubProfileData

  let(:browser) { { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36" } }

  around do |example|
    Rails.configuration.x.github_profile_token = "preview-token"
    example.run
  ensure
    Rails.configuration.x.github_profile_token = nil
  end

  before do
    allow(GithubProfileGateway).to receive(:profile).and_return(github_profile)
    allow(GithubProfileGateway).to receive(:commits).and_return([ github_profile_commit ])
  end

  describe "GET /preview" do
    it "sends the username typed to its preview" do
      get "/preview", params: { github: " @Ada " }
      expect(response).to redirect_to("/preview/Ada")
    end

    it "takes a GitHub profile's address pasted" do
      get "/preview", params: { github: "https://github.com/ada/" }
      expect(response).to redirect_to("/preview/ada")
    end

    # The box shows github.com/ before the field, so some will type it too.
    it "takes any GitHub address, a repo's or a tab's giving its owner" do
      [ "github.com/ada", "www.github.com/ada", "https://github.com/ada/engine", "https://github.com/ada?tab=repositories", "@ada" ].each do |typed|
        get "/preview", params: { github: typed }
        expect(response).to redirect_to("/preview/ada"), typed
      end
    end

    it "says so on the landing, the name kept in its box, for a name GitHub could never have" do
      get "/preview", params: { github: "your_username" }

      expect(response).to have_http_status(:unprocessable_content)
      field = Nokogiri::HTML(response.body).at_css("input#preview-login")
      expect([ field["value"], field["aria-invalid"], field.key?("autofocus") ]).to eq([ "your_username", "true", true ])
      expect(Nokogiri::HTML(response.body).at_css("#preview-login-error").text).to eq("No GitHub user named @your_username.")
      expect(response.body).to include("Keep shipping.")
    end

    it "goes home with nothing typed" do
      get "/preview", params: { github: "" }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /preview/:login" do
    it "shows the stage GitHub's public data makes, with the sign-in that claims it, out of search" do
      get "/preview/ada", headers: browser

      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      body = response.body
      expect(body).to include('<meta name="robots" content="noindex, nofollow">')
      expect(body).to include("@ada's stage, built from public GitHub", "Ada Lovelace", "engine", "The analytical engine", "Add the mill")
      expect(body).to include("commits, last 12 months")
      claim = Nokogiri::HTML(body).css("[data-preview-claim] form").first
      expect(claim["action"]).to eq("/auth/github")
      expect([ claim.at_css("button").text.squish, claim.at_css("button")["class"] ]).to eq([ "Make your own stage", "os-btn h-[52px] px-6 text-[17px]" ])
      expect(claim.css("input[name=ref]").first["value"]).to eq("preview")
    end

    it "counts a preview once per username a visitor looks at, by the tag they came with" do
      get "/?ref=reddit", headers: browser
      2.times { get "/preview/ada", headers: browser }
      get "/preview/grace", headers: browser

      expect(Event.named("preview").pluck(:detail)).to eq(%w[reddit reddit])
    end

    it "counts no member's look" do
      sign_in_as(create(:user))
      get "/preview/ada", headers: browser
      expect(Event.named("preview")).to be_empty
    end

    it "opens a member's stage for their GitHub account" do
      create(:user, username: "lovelace", github_username: "Ada")

      get "/preview/ada", headers: browser

      expect(response).to redirect_to("/lovelace")
      expect(GithubProfileGateway).not_to have_received(:profile)
    end

    it "builds nothing for a bot" do
      get "/preview/ada", headers: { "User-Agent" => "Googlebot/2.1" }

      expect(response).to have_http_status(:not_found)
      expect(GithubProfileGateway).not_to have_received(:profile)
    end

    it "answers 404 with the landing for a login GitHub does not know, the login kept in the box" do
      allow(GithubProfileGateway).to receive(:profile).and_raise(ApplicationGateway::NotFound.new(status: 404))

      get "/preview/nobdy", headers: browser

      expect(response).to have_http_status(:not_found)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("input#preview-login")["value"]).to eq("nobdy")
      expect(page.at_css("#preview-login-error").text).to eq("No GitHub user named @nobdy.")
      expect(page.at_css("input#preview-login-end")["value"]).to eq("")
      expect(response.body).to include("Keep shipping.", "How it works")
    end

    it "offers the sign-in when GitHub fails, and reports it" do
      allow(GithubProfileGateway).to receive(:profile).and_raise(ApplicationGateway::ServerError.new(status: 502))
      allow(Rails.error).to receive(:report)

      get "/preview/ada", headers: browser

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("GitHub isn&#39;t answering right now", "Sign in with GitHub")
      expect(Rails.error).to have_received(:report).with(an_instance_of(ApplicationGateway::ServerError), handled: true)
    end

    it "is off without a token" do
      Rails.configuration.x.github_profile_token = nil

      get "/preview/ada", headers: browser

      expect(response).to have_http_status(:service_unavailable)
      expect(GithubProfileGateway).not_to have_received(:profile)
    end

    it "stops a visitor past their previews for the hour" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      PreviewsController::PER_VISITOR.times { get "/preview/ada", headers: browser }
      expect(response).to have_http_status(:ok)

      get "/preview/ada", headers: browser
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("Too many previews this hour")
    end

    it "shows the public repos the stage would show, for someone with no commits in the 12 months" do
      allow(GithubProfileGateway).to receive(:profile).and_return(github_profile(repos: []))
      allow(GithubProfileGateway).to receive(:recent_repos).and_return([ github_recent_repo(homepage: "https://notes.example") ])

      get "/preview/ada", headers: browser

      repos = Nokogiri::HTML(response.body).at_css("section[aria-labelledby='public-repos']")
      expect(repos.at_css("h2").text).to eq("Public repos")
      expect(repos.text.squish).to include("notes", "Notes on the engine", "Ruby · updated Apr 2024", "notes.example")
      expect(repos.text).not_to match(/star/i)
    end

    it "names the private work GitHub counts, when they share it" do
      allow(GithubProfileGateway).to receive(:profile).and_return(github_profile(repos: [], private_contributions: 1240))
      allow(GithubProfileGateway).to receive(:recent_repos).and_return([])

      get "/preview/ada", headers: browser

      expect(Nokogiri::HTML(response.body).text.squish)
        .to include("GitHub counts 1,240 private contributions in that time. Add those repos once it's yours, and their commits show here.")
      expect(response.body).not_to include("public-repos")
    end

    it "says so for someone with no public commits in the 12 months" do
      allow(GithubProfileGateway).to receive(:profile).and_return(github_profile(repos: []))
      allow(GithubProfileGateway).to receive(:recent_repos).and_return([])

      get "/preview/ada", headers: browser

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No public commits in the last 12 months", "Once it's yours, it fills as you push. Private repos can join it too.")
      # The top's sign-in stays; the end's, with nothing to keep current, goes.
      expect(Nokogiri::HTML(response.body).css("main form[action='/auth/github'] button").map { |b| b.text.squish }).to eq([ "Make your own stage" ])
      expect(response.body).not_to include("Keep it current")
    end
  end

  it "keeps the username preview from ever being claimed" do
    expect(User::RESERVED_USERNAMES).to include("preview")
  end
end
