require "rails_helper"

RSpec.describe "Share and RSS", type: :request do
  let!(:user) { create(:user, username: "builder", display_name: "Bea", bio: "Building things") }

  before do
    create(:entry, user: user, entry_type: "shipped", source: "github", title: "Ship it", repo_name: "builder/app",
                   external_id: "s1", url: "https://github.com/builder/app/commit/abc", occurred_at: 1.day.ago)
    create(:entry, user: user, entry_type: "shipped", source: "github", title: "Bump rack from 1 to 2", repo_name: "builder/app",
                   external_id: "s2", occurred_at: 1.day.ago)
    create(:entry, user: user, entry_type: "note", source: "manual", title: "A thought", body: "Longer body here", occurred_at: 2.days.ago)
  end

  it "offers share and RSS on the profile, with no counts" do
    get "/builder"
    expect(response.body).to include("data-share-button")
    expect(response.body).to include('href="http://www.example.com/builder.rss"')
    expect(response.body).to include('type="application/rss+xml"')
  end

  it "serves a de-noised RSS feed" do
    get "/builder.rss"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/rss+xml")
    expect(response.body).to include("<title>Bea on Openstage</title>")
    expect(response.body).to include("<title>Ship it</title>")
    expect(response.body).to include("https://github.com/builder/app/commit/abc")
    expect(response.body).to include("Longer body here")
    expect(response.body).not_to include("Bump rack")
  end

  it "404s the feed for an unknown builder" do
    get "/nobody-here.rss"
    expect(response).to have_http_status(:not_found)
  end
end
