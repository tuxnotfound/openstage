require "rails_helper"

RSpec.describe "Project pages", type: :request do
  let(:user) { create(:user, username: "builder", display_name: "Bea") }

  before do
    create(:github_repo, user: user, full_name: "builder/side.app", name: "side.app", description: "A small app.", homepage: "https://side.example")
    create(:entry, user: user, repo_name: "builder/side.app", title: "Ship the form")
    create(:entry, user: user, repo_name: "builder/other", title: "Other work")
    create(:entry, user: user, repo_name: "builder/side.app", entry_type: "milestone", source: "manual", title: "Launched it", body: "In my words.")
  end

  it "shows the project: what it is, its commits, what's new and the other projects" do
    get "/builder/side.app"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("A small app.", "Visit side.example", "Ship the form", "Launched it", "In my words.")
    expect(response.body).to include(%(href="/builder/other"))
    expect(response.body).not_to include("Other work")
  end

  it "finds the project whatever the case of its name" do
    get "/builder/SIDE.APP"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(rel="canonical" href="http://www.example.com/builder/side.app"))
  end

  it "opens on another window from the pills" do
    get "/builder/side.app", params: { range: "30d" }

    expect(response.body).to include("Commits · last 30 days")
  end

  it "sends a name that is no project back to the builder's page" do
    get "/builder/nope"

    expect(response).to redirect_to("/builder")
  end

  it "answers 404 for a builder who does not exist" do
    get "/nobody/side.app"

    expect(response).to have_http_status(:not_found)
  end

  it "is linked from the builder's page and listed in the sitemap" do
    get "/builder"
    expect(response.body).to include(%(href="/builder/side.app"))

    get "/sitemap.xml"
    expect(response.body).to include("http://www.example.com/builder/side.app")
  end
end
