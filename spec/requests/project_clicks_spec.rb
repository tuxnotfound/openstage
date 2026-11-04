require "rails_helper"

RSpec.describe "Project page buttons", type: :request do
  let(:user) { create(:user, username: "builder") }
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" } }
  let!(:repo) { create(:github_repo, user: user, full_name: "builder/side.app", name: "side.app", homepage: "https://side.example") }

  before { create(:entry, user: user, repo_name: "builder/side.app") }

  it "sends the project page's buttons through the count" do
    get "/builder/side.app"

    expect(response.body).to include(%(href="/builder/side.app/visit"), %(href="/builder/side.app/github"))
  end

  it "counts a click on Visit and sends the visitor to the website" do
    expect { get "/builder/side.app/visit", headers: browser }.to change(user.project_clicks, :count).by(1)

    expect(response).to redirect_to("https://side.example")
    expect(user.project_clicks.last).to have_attributes(repo_name: "builder/side.app", kind: "visit")
  end

  it "counts a click on View on GitHub and sends the visitor to the repo" do
    get "/builder/SIDE.APP/github", headers: browser

    expect(response).to redirect_to("https://github.com/builder/side.app")
    expect(user.project_clicks.last.kind).to eq("github")
  end

  it "never sends anyone to a private repo or a website that is not http(s)" do
    repo.update!(private_repo: true, homepage: "javascript:alert(1)")

    get "/builder/side.app/github", headers: browser
    expect(response).to redirect_to("/builder/side.app")
    get "/builder/side.app/visit", headers: browser
    expect(response).to redirect_to("/builder/side.app")
    expect(user.project_clicks.count).to eq(0)
  end

  it "never counts the builder's own click or a bot's" do
    get "/builder/side.app/visit", headers: { "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }
    sign_in_as(user)
    get "/builder/side.app/visit", headers: browser

    expect(response).to redirect_to("https://side.example")
    expect(user.project_clicks.count).to eq(0)
  end

  it "sends an unknown builder home" do
    get "/nobody/side.app/visit"

    expect(response).to redirect_to("/")
  end
end
