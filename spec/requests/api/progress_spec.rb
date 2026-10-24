require "rails_helper"

RSpec.describe "Api::Progress", type: :request do
  let(:user) { create(:user, username: "builder") }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/lib", occurred_at: 40.days.ago)
    create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 2.days.ago)
  end

  def json
    response.parsed_body
  end

  it "answers the view asked for, camelCased, as the page renders it" do
    get "/api/progress/builder", params: { range: "30d" }

    expect(response).to have_http_status(:ok)
    expect(json).to include("range" => "30d", "commits" => 3, "scope" => "all 2 projects", "words" => "last 30 days")
    expect(json["kpis"]).to eq("1 shipped · 0 published · 1 project with commits · 3 active days")
    expect(json["chart"]).to include("ariaLabel" => "7-day average of commits per day by project, last 30 days", "empty" => false)
    expect(json["chart"]["paths"].size).to eq(1)
    expect(json["shipped"]["items"].map { |item| item["title"] }).to eq([ "Launched" ])

    get "/builder", params: { range: "30d" }
    expect(Nokogiri::HTML(response.body).at_css("section[aria-label='Profile'] .os-big").text).to eq("3")
  end

  it "narrows to the projects picked" do
    get "/api/progress/builder", params: { range: "90d", repo: [ "builder/lib" ] }

    expect(json).to include("commits" => 1, "scope" => "lib", "filtered" => true, "selected" => [ "builder/lib" ])
    expect(json["projects"].map { |project| [ project["name"], project["on"] ] }).to eq([ [ "app", false ], [ "lib", true ] ])
  end

  it "never counts a hidden or private entry" do
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 1.day.ago, hidden: true)
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 1.day.ago, visibility: :private_entry)

    get "/api/progress/builder", params: { range: "30d" }

    expect(json["commits"]).to eq(3)
  end

  it "lets a browser revalidate a view it has" do
    get "/api/progress/builder", params: { range: "12m" }
    etag = response.headers["ETag"]

    get "/api/progress/builder", params: { range: "12m" }, headers: { "If-None-Match" => etag }
    expect(response).to have_http_status(:not_modified)
  end

  it "caches a view until the builder's public work changes" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    get "/api/progress/builder", params: { range: "30d" }
    expect(json["commits"]).to eq(3)

    allow(Progress::ComposeService).to receive(:new).and_call_original
    get "/api/progress/builder", params: { range: "30d" }
    expect(Progress::ComposeService).not_to have_received(:new)

    user.entries.where(source: "github").first.update_columns(hidden: true)
    get "/api/progress/builder", params: { range: "30d" }
    expect(json["commits"]).to eq(2)
  end

  it "answers 404 for a builder who does not exist" do
    get "/api/progress/nobody"

    expect(response).to have_http_status(:not_found)
  end
end
