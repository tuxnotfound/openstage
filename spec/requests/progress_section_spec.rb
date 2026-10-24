require "rails_helper"
require "support/progress_data"

RSpec.describe "The public page's chart and what shipped" do
  include ProgressData

  let(:user) { create(:user, username: "tux") }
  let(:today) { ProgressData::TODAY.to_date }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def panel
    Nokogiri::HTML(response.body).at_css("section[aria-label='Profile']")
  end

  def shipped
    Nokogiri::HTML(response.body).at_css("section[aria-labelledby='what-shipped']").text.squish
  end

  it "opens on the last 12 months, with the counts, and what shipped below" do
    get "/tux"

    expect(panel.at_css(".os-label").text.squish).to eq("Commits · all 7 projects, last 12 months")
    expect(panel.at_css(".os-big").text).to eq(progress_commits(Date.new(2025, 11, 1)..today).to_s)
    expect(panel.text.squish).to include("since the first commit, March 26",
                                         "10 shipped · 10 published · 7 projects with commits · 64 active days")
    expect(shipped).to include("20 in the last 12 months", "live on Hacker News")
  end

  it "measures 30 and 90 days against the same stretch just before" do
    get "/tux", params: { range: "30d" }
    now = progress_commits((today - 29)..today)
    before = progress_commits((today - 59)..(today - 30))
    expect(panel.at_css(".os-big").text).to eq(now.to_s)
    expect(panel.text.squish).to include("#{((100.0 * now / before) - 100).round.abs}% vs the previous 30 days")

    get "/tux", params: { range: "90d" }
    monday = today - (today.cwday - 1) - 84
    now = progress_commits(monday..today)
    before = progress_commits((monday - 91)..(today - 91))
    expect(panel.at_css(".os-big").text).to eq(now.to_s)
    expect(panel.text.squish).to include("#{((100.0 * now / before) - 100).round.abs}% vs the previous 90 days")
  end

  # The work began in March 2026, so 12 months are drawn from March: 8 points.
  it "draws 30 days as a 7-day average and the other windows as counts per point, from the first commit" do
    { "30d" => [ "7-day average of commits per day by project, last 30 days", 30 ],
      "90d" => [ "Commits per week by project, last 90 days", 13 ],
      "12m" => [ "Commits per month by project, last 12 months", 8 ] }.each do |range, (label, points)|
      get "/tux", params: { range: range }

      expect(panel.at_css("svg[role='img']")["aria-label"]).to eq(label)
      expect(panel.css("[data-chart-tooltip-template-param]").size).to eq(points)
    end
  end

  it "says so when the window holds nothing" do
    travel_to ProgressData::TODAY + 60.days
    get "/tux", params: { range: "30d" }

    expect(panel.text).to include("No commits in the last 30 days.")
    expect(shipped).to include("Nothing shipped or published in the last 30 days.")
    expect(panel.css("svg[role='img'] path")).to be_empty
  end

  it "scopes the page to the projects picked, counting only tagged entries" do
    get "/tux", params: { repo: progress_repo(4) }

    expect(panel.at_css(".os-label").text.squish).to eq("Commits · trained-on, last 12 months")
    expect(panel.at_css(".os-big").text).to eq(progress_commits(Date.new(2025, 11, 1)..today, [ 4 ]).to_s)
    expect(shipped).to include("Trained on me is live!!")

    get "/tux", params: { repo: progress_repo(0) }
    expect(shipped).to include("No entries tagged openstage in the last 12 months.")
  end

  def switch_for(name)
    panel.at_css("[aria-label='Projects'] [role='switch'][aria-label='Show #{name} in the chart']")
  end

  it "switches a project in or out beside the chart, keeping the window on every link" do
    get "/tux", params: { range: "90d" }
    switch = switch_for("openstage")
    query = Rack::Utils.parse_nested_query(URI(switch["href"]).query)

    expect(switch["aria-checked"]).to eq("true")
    expect(query["range"]).to eq("90d")
    expect(query["repo"]).to match_array((1..6).map { |i| progress_repo(i) })

    get switch["href"]
    expect(switch_for("openstage")["aria-checked"]).to eq("false")
    expect(switch_for("openstage")["href"]).to eq("/tux?range=90d")
    expect(panel.at_css("[aria-label='Projects'] a", text: "Show all")["href"]).to eq("/tux?range=90d")
    windows = panel.css("nav[aria-label='Time range'] a").to_h { |a| [ a.text, a["href"] ] }
    expect(windows["12 months"]).to start_with("/tux?repo%5B%5D=")
    expect(windows["30 days"]).to include("range=30d")
  end

  it "keeps the last project in view on: its switch cannot turn it off" do
    get "/tux", params: { repo: [ progress_repo(0) ] }

    expect(switch_for("openstage")).to have_attributes(name: "span")
    expect(switch_for("openstage")["aria-disabled"]).to eq("true")
    expect(switch_for("wheels-off")["aria-checked"]).to eq("false")
  end

  it "draws the lines alone, with no numbered discs or list beside the chart" do
    get "/tux"

    expect(panel.css(".os-disc")).to be_empty
    expect(panel.css("ol")).to be_empty
    expect(panel.css("svg[role='img'] path[stroke-width='4.5']").size).to eq(7)
  end

  it "shows the owner, and only the owner, the tag line, and nobody Make a card" do
    get "/tux"
    expect(panel.text).not_to include("have no project")

    sign_in_as(user)
    get "/tux"
    expect(panel.at_css("turbo-frame#progress_card")).to be_nil
    expect(panel.text.squish).to include("#{progress_untagged(Date.new(2025, 11, 1)..today)} entries in the last 12 months have no project. Tag them")
  end

  it "shows several projects at once, and the rest of the page follows them" do
    create(:entry, user: user, repo_name: progress_repo(1), title: "A wheels-off commit", occurred_at: 1.hour.ago)
    create(:entry, user: user, repo_name: progress_repo(2), title: "A goal_atlas commit", occurred_at: 1.hour.ago)
    get "/tux", params: { repo: [ progress_repo(0), progress_repo(1) ] }

    expect(panel.at_css(".os-label").text.squish).to eq("Commits · openstage + wheels-off, last 12 months")
    expect(response.body).to include("A wheels-off commit")
    expect(response.body).not_to include("A goal_atlas commit")
  end
end
