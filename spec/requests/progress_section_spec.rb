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

  def toggles
    panel.css("[aria-label='Numbers on the chart'] > *").map { |toggle| toggle.text.squish }
  end

  def table_rows
    panel.css("[data-chart-row]").map { |row| row.text.squish }
  end

  it "opens on the last 12 months, every project, the number in its toggle and no figure over the chart" do
    get "/tux"

    expect(toggles).to eq([ "Commits #{progress_commits(Date.new(2025, 11, 1)..today)}" ])
    expect(panel.css(".os-big, .os-sharebar")).to be_empty
    expect(panel.text).not_to include("active days")
    expect(table_rows.first).to eq("openstage Only Commits #{progress_commits(Date.new(2025, 11, 1)..today, [ 0 ])}")
    expect(shipped).to include("20 in the last 12 months", "live on Hacker News")
  end

  it "counts 30 and 90 days in the toggle and in each project's row" do
    get "/tux", params: { range: "30d" }
    expect(toggles).to eq([ "Commits #{progress_commits((today - 29)..today)}" ])

    get "/tux", params: { range: "90d" }
    monday = today - (today.cwday - 1) - 84
    expect(toggles).to eq([ "Commits #{progress_commits(monday..today)}" ])
    expect(table_rows.last).to end_with(progress_commits(monday..today, [ 6 ]).to_s)
  end

  # The work began in March 2026, so 12 months are drawn from March: 8 points.
  it "draws 30 days as a 7-day average and the other windows as counts per point, from the first commit" do
    { "30d" => [ "7-day average of commits per day by project, last 30 days", 30 ],
      "90d" => [ "Commits per week by project, last 90 days", 13 ],
      "12m" => [ "Commits per month by project, last 12 months", 8 ] }.each do |range, (label, points)|
      get "/tux", params: { range: range }

      expect(panel.at_css("svg[role='img']")["aria-label"]).to eq(label)
      expect(panel.at_css("svg[role='img'] path")["d"].scan(/[ML]/).size).to eq(points)
    end
  end

  it "says so when the window holds nothing" do
    travel_to ProgressData::TODAY + 60.days
    get "/tux", params: { range: "30d" }

    expect(panel.text).to include("No commits in the last 30 days.")
    expect(shipped).to include("Nothing shipped or published in the last 30 days.")
    expect(panel.css("svg[role='img'] path")).to be_empty
  end

  it "scopes the page to the projects picked, counting only tagged entries, from the old links too" do
    get "/tux", params: { repo: progress_repo(4) }

    expect(toggles).to eq([ "Commits #{progress_commits(Date.new(2025, 11, 1)..today, [ 4 ])}" ])
    expect(shipped).to include("Trained on me is live!!")

    get "/tux", params: { projects: progress_repo(0) }
    expect(shipped).to include("No entries tagged openstage in the last 12 months.")
  end

  # A row's box, which comes first in its header: a link to its view, current
  # while the row is in view.
  def box_for(name)
    panel.css("[data-chart-row] th > span > :first-child").find { |box| box.text.squish == name }
  end

  def query_of(link)
    Rack::Utils.parse_query(URI(link["href"]).query)
  end

  it "switches a project in or out with its box in the table, keeping the window on every link" do
    get "/tux", params: { range: "90d" }
    box = box_for("openstage")

    expect(box["aria-current"]).to eq("true")
    expect(query_of(box)).to eq("range" => "90d", "projects" => (1..6).map { |i| progress_repo(i) }.join(","))

    get box["href"]
    expect(box_for("openstage")["aria-current"]).to be_nil
    expect(box_for("openstage")["href"]).to eq("/tux?range=90d")
    expect(panel.at_css("[data-chart-table] a", text: "Show all")["href"]).to eq("/tux?range=90d")
    windows = panel.css("[aria-label='Time range'] a").to_h { |a| [ a.text, query_of(a) ] }
    expect(windows["12 months"].keys).to eq([ "projects" ])
    expect(windows["30 days"]).to include("range" => "30d")
  end

  it "shows one project alone with Only, and keeps the last project in view on" do
    get "/tux", params: { range: "90d" }
    only = panel.at_css("[data-chart-row='#{progress_repo(1)}'] a[aria-label='Show only wheels-off']")
    expect(query_of(only)).to eq("range" => "90d", "projects" => progress_repo(1))

    get "/tux", params: { projects: progress_repo(0) }
    expect(box_for("openstage")).to have_attributes(name: "span")
    expect(box_for("openstage").to_h.slice("role", "aria-disabled", "aria-current")).to eq("role" => "link", "aria-disabled" => "true", "aria-current" => "true")
    expect(box_for("wheels-off")["aria-current"]).to be_nil
    expect(panel.at_css("[data-chart-row='#{progress_repo(0)}'] a[aria-label^='Show only']")).to be_nil
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
    get "/tux", params: { projects: [ progress_repo(0), progress_repo(1) ].join(",") }

    expect(panel.css("[data-chart-row] th > span > [aria-current='true']").map { |box| box.text.squish }).to eq(%w[openstage wheels-off])
    expect(response.body).to include("A wheels-off commit")
    expect(response.body).not_to include("A goal_atlas commit")
  end

  it "keeps each number's own line on the first paint, as the URL orders them" do
    get "/tux", params: { show: "commits" }

    expect(panel.css("svg[role='img'] path").map { |path| path["stroke-dasharray"] }.uniq).to eq([ nil ])
    expect(panel.at_css("[aria-label='Time range'] a", text: "30 days")["href"]).to eq("/tux?range=30d")
  end
end
