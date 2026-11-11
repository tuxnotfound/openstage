require "rails_helper"

RSpec.describe "Api::Projects", type: :request do
  let(:user) { create(:user, username: "builder") }

  before do
    travel_to Time.utc(2026, 11, 10, 12)
    10.times { |i| 3.times { create(:entry, user: user, repo_name: "builder/top#{i}", occurred_at: 1.day.ago) } }
    create(:github_repo, user: user, full_name: "builder/sauna", description: "Sauna math.", homepage: "https://sauna.example")
    create(:entry, user: user, repo_name: "builder/sauna", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "builder/fire", occurred_at: 9.days.ago)
  end

  def json
    response.parsed_body
  end

  it "answers a page of the projects past the cards, camelCased, as the stage renders it" do
    get "/api/projects/builder"

    expect(response).to have_http_status(:ok)
    expect(json).to include("title" => "2 more projects", "sort" => "latest", "query" => "", "live" => false, "page" => 1, "pages" => 1,
                            "liveLabel" => "Live · 1", "range" => "1–2 of 2", "empty" => nil)
    expect(json["sorts"].map { |sort| sort["label"] }).to eq([ "Latest", "Most commits", "A–Z" ])
    sauna = json["rows"].first
    expect(sauna).to include("key" => "builder/sauna", "name" => "sauna", "path" => "/builder/sauna", "description" => "Sauna math.", "live" => true,
                             "archived" => false, "commits" => 1, "last" => "2 days ago")
    expect(sauna["line"]).to start_with("M0.0 ")
    expect(json["rows"].map { |row| row["name"] }).to eq(%w[sauna fire])
  end

  it "sorts, finds and filters as asked, and says why it finds nothing" do
    get "/api/projects/builder", params: { sort: "name" }
    expect(json["rows"].map { |row| row["name"] }).to eq(%w[fire sauna])

    get "/api/projects/builder", params: { live: "1" }
    expect(json["rows"].map { |row| row["name"] }).to eq(%w[sauna])

    get "/api/projects/builder", params: { q: "kale" }
    expect(json).to include("rows" => [], "range" => nil, "empty" => %(No project named "kale".))
  end

  it "may be cached anywhere, and answers a browser that has it with Not Modified" do
    get "/api/projects/builder"
    expect(response.headers["Cache-Control"]).to include("public")

    get "/api/projects/builder", headers: { "If-None-Match" => response.headers["ETag"] }
    expect(response).to have_http_status(:not_modified)
  end

  it "answers Not Found for a builder who is not there" do
    get "/api/projects/nobody"

    expect(response).to have_http_status(:not_found)
  end
end
