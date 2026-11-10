require "rails_helper"

RSpec.describe "Counts a visitor never reads at zero", type: :request do
  let(:user) { create(:user, username: "builder") }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:github_repo, user: user, full_name: "builder/old", name: "old")
    create(:entry, user: user, repo_name: "builder/old", title: "Last of it", occurred_at: 400.days.ago)
    create(:entry, user: user, repo_name: "builder/plans", entry_type: "milestone", source: "manual", title: "Opened the waitlist", occurred_at: 60.days.ago)
  end

  def html
    Nokogiri::HTML(response.body)
  end

  it "leaves a project's card on the stage without its commits while it has none in 12 months" do
    get "/builder"

    cards = html.css("section[aria-labelledby='projects'] .os-card").map { |card| card.text.squish }
    expect(cards.size).to eq(2)
    expect(cards.join).not_to include("0 commits", "commits in 12 months")
    expect(html.at_css("section[aria-labelledby='projects']").text).not_to include("Commits per week")
  end

  it "says no count in What's new for a window with nothing shipped or published, in the page and the JSON" do
    get "/builder", params: { range: "30d" }

    expect(html.at_css("#whats-new-panel .os-between").text.squish).to eq("What's new")
    expect(html.at_css("#whats-new-panel").text).to include("Nothing shipped or published in the last 30 days.")

    get "/api/progress/builder", params: { range: "30d" }
    expect(response.parsed_body["shipped"]).to include("heading" => nil)

    get "/api/progress/builder", params: { range: "90d" }
    expect(response.parsed_body["shipped"]["heading"]).to eq("1 in the last 90 days")
  end

  it "gives a project with no commits no count of them in its details" do
    get "/builder/plans"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Commits, all time")
  end
end
