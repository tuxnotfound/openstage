require "rails_helper"

RSpec.describe "Set up site visits", type: :request do
  let(:user) { create(:user, username: "builder", github_username: "builder", pro: true, time_zone: "Europe/Lisbon") }
  let!(:repo) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote", homepage: "https://shipnote.app") }
  let!(:bare) { create(:github_repo, user: user, name: "aardvark", full_name: "builder/aardvark") }

  before do
    [ repo, bare ].each { |each| create(:entry, user: user, repo_name: each.full_name, occurred_at: 2.days.ago) }
    sign_in_as(user)
  end

  def props
    JSON.parse(Nokogiri::HTML(response.body).at_css("#site-setup-props").text)
  end

  it "opens on the project the link asked for, among the projects on the stage by name, its website as the app reads it" do
    get "/dashboard/site-visits", params: { project: repo.id }

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("h1").text).to eq("Set up site visits")
    expect(page.at_css("nav[aria-label='Breadcrumb'] a")["href"]).to eq("/dashboard")
    expect(props["projects"]).to eq([ { "id" => bare.id, "label" => "aardvark" }, { "id" => repo.id, "label" => "shipnote" } ])
    expect(props["project"]).to include("id" => repo.id, "name" => "shipnote", "host" => "shipnote.app", "website" => "https://shipnote.app", "line" => nil)
    expect(props["status"]).to eq("step" => "pick", "firstVisit" => nil, "seen" => true)
    expect(props).to include("free" => false, "refusal" => nil)
  end

  it "picks the first project with a website when no link names one, and leaves a project off the stage out unless asked for" do
    hidden = create(:github_repo, user: user, name: "zeta", full_name: "builder/zeta", included: false, homepage: "https://zeta.dev")
    create(:entry, user: user, repo_name: hidden.full_name, occurred_at: 2.days.ago)

    get "/dashboard/site-visits"
    expect(props["project"]["id"]).to eq(repo.id)
    expect(props["projects"].pluck("label")).to eq(%w[aardvark shipnote])

    get "/dashboard/site-visits", params: { project: hidden.id }
    expect(props["project"]["id"]).to eq(hidden.id)
    expect(props["projects"].pluck("label")).to eq(%w[aardvark shipnote zeta])
  end

  it "never opens another builder's project" do
    stranger = create(:github_repo, homepage: "https://stranger.dev")

    get "/dashboard/site-visits", params: { project: stranger.id }
    expect(props["project"]["id"]).to eq(repo.id)

    patch "/dashboard/site-visits", params: { project_id: stranger.id, website: "https://stranger.dev" }
    expect(response).to have_http_status(:not_found)
    expect(stranger.reload.site_source).to be_nil
  end

  it "keeps the website and picks the script on Continue, then opens on the line to paste and the wait" do
    patch "/dashboard/site-visits", params: { project_id: repo.id, website: "https://shipnote.app" }

    expect(response).to redirect_to("/dashboard/site-visits?project=#{repo.id}")
    expect(repo.reload).to have_attributes(site_source: "script", website_edit: nil)
    follow_redirect!
    expect(props["status"]).to eq("step" => "line", "firstVisit" => nil, "seen" => true)
    expect(props["project"]["line"]).to eq(%(<script defer src="http://www.example.com/v.js" data-project="#{repo.site_token}"></script>))
    expect(props["project"]["note"]).to start_with("It counts only on shipnote.app. No cookie:")
    expect(props["project"]).to include("visit" => "https://shipnote.app", "statusPath" => "/api/site_visits/#{repo.id}",
                                        "numbers" => "/projects/#{repo.id}/numbers", "page" => "/builder/shipnote",
                                        "dashboard" => "/dashboard?project=#{repo.id}")
  end

  it "keeps a website the builder types as their own, the one the script counts on" do
    patch "/dashboard/site-visits", params: { project_id: bare.id, website: "https://aardvark.dev" }

    expect(bare.reload).to have_attributes(website_edit: "https://aardvark.dev", site_source: "script", site_host: "aardvark.dev")
  end

  it "says in the first step why it refuses, in the app's words, and keeps nothing" do
    patch "/dashboard/site-visits", params: { project_id: bare.id, website: "" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(props["refusal"]).to eq("Add aardvark's website first: the script counts only there.")
    expect(props["status"]["step"]).to eq("pick")

    patch "/dashboard/site-visits", params: { project_id: bare.id, website: "aardvark.dev" }
    expect(props["refusal"]).to eq("Website edit must start with http:// or https://")
    expect(props["project"]["website"]).to eq("aardvark.dev")
    expect(bare.reload).to have_attributes(website_edit: nil, site_source: nil)
  end

  it "opens with every step done once the first visit came" do
    travel_to Time.utc(2026, 11, 25, 14, 2)
    repo.update!(site_source: "script", site_token: "os_a", site_set_up_at: 1.hour.ago, site_first_visit_at: Time.current)

    get "/dashboard/site-visits", params: { project: repo.id }

    expect(props["status"]).to eq("step" => "done", "firstVisit" => "First visit received today at 14:02", "seen" => true)
  end

  it "asks a builder with no project yet to connect GitHub" do
    Entry.delete_all

    get "/dashboard/site-visits"

    expect(props).to include("projects" => [], "project" => nil, "status" => nil)
    expect(props["paths"]["connect"]).to eq("/github_app/install")
  end

  it "sends someone signed out to sign in" do
    delete "/sign_out"
    get "/dashboard/site-visits"

    expect(response).to redirect_to(root_path)
  end

  context "on Free" do
    let(:user) { create(:user, username: "builder", github_username: "builder", pro: false) }
    let!(:tidepool) do
      create(:github_repo, user: user, name: "tidepool", full_name: "builder/tidepool", homepage: "https://tidepool.dev",
                           site_set_up_at: 10.days.ago)
    end

    before { create(:entry, user: user, repo_name: tidepool.full_name, occurred_at: 2.days.ago) }

    it "opens on the one project Free counts, and says so" do
      get "/dashboard/site-visits"

      expect(props["project"]["id"]).to eq(tidepool.id)
      expect(props["free"]).to be(true)
      expect(props["paths"]["pricing"]).to eq("/pricing")
    end

    it "refuses a second project, says why in Free's words, and keeps its website as it was" do
      patch "/dashboard/site-visits", params: { project_id: bare.id, website: "https://aardvark.dev" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(props["refusal"]).to eq("Free counts site visits for one project, tidepool. Go Pro to count them for every project.")
      expect(bare.reload).to have_attributes(website_edit: nil, site_source: nil, site_set_up_at: nil)
    end
  end
end
