require "rails_helper"

# Hiding an entry on the dashboard takes it off every list and out of no
# number: a repo with 4 commits, one hidden, still counts 4 everywhere, and
# lists 3 (Pedro, 2026-10-30).
RSpec.describe "Entries the builder hid", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:github_repo, user: user, full_name: "builder/app", name: "app")
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", title: "Shown commit #{i}", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/app", title: "Hidden commit", occurred_at: 1.hour.ago, hidden: true)
    create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Shown launch", occurred_at: 3.days.ago)
    create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Hidden launch",
                   occurred_at: 2.hours.ago, hidden: true)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def numbers_on_chart
    page.at_css("[aria-label='Numbers on the chart']").text.squish
  end

  def expect_none_listed
    expect(response.body).not_to include("Hidden commit")
    expect(response.body).not_to include("Hidden launch")
  end

  it "counts them on the builder's page, its cards and its facts, and lists neither" do
    get "/builder", params: { range: "30d" }

    expect(numbers_on_chart).to eq("Commits 4")
    expect(page.at_css("main").text.squish).to include("6 entries", "2 milestones", "4-day streak")
    expect(page.at_css("#what-shipped-panel").text.squish).to include("Shown launch")
    expect(response.body).to include("Shown commit 0")
    expect_none_listed
  end

  it "counts them on the project's page, and lists neither, its latest news included" do
    get "/builder/app", params: { range: "30d" }

    details = page.css("dl div, dl > *").map { |node| node.text.squish }.join(" | ")
    expect(numbers_on_chart).to eq("Commits 4")
    expect(details).to include("Commits, all time 4", "Shipped and published 2")
    expect(response.body).to include("Shown launch")
    expect_none_listed
  end

  it "counts them in the API's view, and leaves them out of its What shipped" do
    get "/api/progress/builder", params: { range: "30d" }

    json = response.parsed_body
    expect(json["numbers"].to_h { |number| [ number["key"], number["value"] ] }).to eq("commits" => "4")
    expect(json["table"]).to be_nil
    expect(json["shipped"]["items"].map { |item| item["title"] }).to eq([ "Shown launch" ])
  end

  # The hide, in frozen time, changes the key by how many entries the lists
  # show alone; the restore, a minute on, by its edit too.
  it "refreshes the API's cached view when one is hidden or restored, its numbers as they were" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    launch = user.entries.find_by!(title: "Shown launch")
    titles = -> { get("/api/progress/builder", params: { range: "30d" }) && response.parsed_body["shipped"]["items"].map { |item| item["title"] } }

    expect(titles.call).to eq([ "Shown launch" ])
    launch.update!(hidden: true)
    expect(titles.call).to eq([])
    expect(response.parsed_body["numbers"].first["value"]).to eq("4")
    travel 1.minute
    user.entries.find_by!(title: "Hidden launch").update!(hidden: false)
    expect(titles.call).to eq([ "Hidden launch" ])
  end

  it "counts them in the dashboard's table, and in the rank that gives each project its colour" do
    create(:github_repo, user: user, full_name: "builder/aaa", name: "aaa")
    3.times { |i| create(:entry, user: user, repo_name: "builder/aaa", occurred_at: (i + 1).days.ago) }
    sign_in_as(user)

    get "/api/progress/builder", params: { range: "30d", dashboard: 1 }

    rows = response.parsed_body["table"]["rows"].map { |row| [ row["name"], row["cells"].first["value"] ] }
    expect(rows).to eq([ [ "app", "4" ], [ "aaa", "3" ] ])
  end

  it "counts them on the badge" do
    get "/badge/builder"

    expect(response.body).to include("4 commits | 6 entries")
  end

  it "lists neither in the embed, the RSS feed, the feed, the landing's Lately strip or a link to one entry" do
    get "/embed/builder.js"
    expect(response.body).to include("Shown commit 0")

    get "/builder.rss"
    expect(response.body).to include("Shown commit 0")
    expect_none_listed

    get "/feed"
    expect(response.body).to include("Shown launch")
    expect_none_listed

    get "/"
    expect_none_listed

    get "/builder", params: { entry: user.entries.find_by!(title: "Hidden launch").id }
    expect(page.at_css("#linked-entry, [data-linked-entry]")).to be_nil
  end

  it "dates the builder's page in the sitemap from the newest, hidden or not" do
    get "/sitemap.xml"

    urls = Nokogiri::XML(response.body).remove_namespaces!.css("url").to_h { |url| [ url.at_css("loc").text, url.at_css("lastmod")&.text ] }
    expect(urls.fetch("http://www.example.com/builder")).to eq("2026-10-24T11:00:00Z")
  end

  it "counts them on the dashboard's numbers, and lists them only under Hidden" do
    sign_in_as(user)
    get "/dashboard"

    expect(page.at_css("section[data-recap-prompt]").text.squish).to include("You shipped 4 commits in app", "You logged 2 updates")
    expect(page.at_css("[data-tabs-panel='timeline']").text).not_to include("Hidden commit", "Hidden launch")
    expect(page.at_css("[data-tabs-panel='hidden']").text).to include("Hidden commit", "Hidden launch")
  end

  it "counts them in analytics" do
    sign_in_as(user)
    get "/analytics", params: { range: "30d" }

    expect(page.at_css("[aria-label='Numbers on the chart']").text.squish).to start_with("On GitHub Commits 4")
  end

  it "counts them on the project's own view and its share cards" do
    gather = Projects::GatherService.new(repo: user.github_repos.first).tap(&:call!)
    cards = ShareCards::GatherService.new(user: user)
    allow(AvatarGateway).to receive(:image).and_return(nil)
    cards.call!

    expect([ gather.commits, gather.last_commit ]).to eq([ 4, Date.new(2026, 10, 24) ])
    expect(cards.cards.map { |card| [ card.name, card.commits, card.last_commit ] }).to eq([ [ "app", 4, Date.new(2026, 10, 24) ] ])
  end
end
