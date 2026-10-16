require "rails_helper"
require "support/progress_data"

RSpec.describe "The progress section of the public page" do
  include ProgressData

  let(:user) { create(:user, username: "tux") }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def section
    Nokogiri::HTML(response.body).at_css("turbo-frame#progress section")
  end

  it "opens on this year, with the counts and the six entries that get words" do
    get "/tux"

    expect(section.at_css("h2").text).to eq("2026")
    expect(section.text.squish).to include("10 Shipped", "10 Published", "380 Commits", "64 Active days", "7 Projects")
    expect(section.css("ol li").map { |row| row.at_css("a").text.squish }.first).to eq("live on Hacker News")
    expect(section.css("ol li").size).to eq(6)
    expect(section.text).to include("14 more in 2026")
  end

  it "steps through calendar periods by range and offset, with the change against the period before" do
    get "/tux", params: { range: "month" }
    expect(section.at_css("h2").text).to eq("October 2026")
    expect(section.text).to include("+127")
    expect(section.css("[title='vs Sep 1–15']").map(&:text)).to include("+127")

    get "/tux", params: { range: "month", offset: -1 }
    expect(section.at_css("h2").text).to eq("September 2026")
    expect(section.css("ol li").size).to eq(5)
  end

  it "says so when a period has nothing logged" do
    get "/tux", params: { range: "week" }

    expect(section.text).to include("Nothing shipped or published this week yet.")
    expect(section.text.squish).to include("79 +46 Commits")
  end

  it "scopes the section with the timeline's repo filter, counting only tagged entries" do
    get "/tux", params: { repo: progress_repo(4) }

    expect(section.text.squish).to include("1 Shipped", "Share of commits")
    expect(section.css("ol li").map { |row| row.at_css("a").text.squish }).to eq([ "Trained on me is live!!" ])

    get "/tux", params: { repo: progress_repo(0) }
    expect(section.text).to include("No entries tagged openstage in 2026.")
  end

  it "keeps the other params on its links and drops the offset when the range changes" do
    get "/tux", params: { range: "month", offset: -1, repo: progress_repo(0) }

    month_link = section.css("nav[aria-label='Time range'] a").find { |a| a.text == "Week" }
    expect(month_link["href"]).to eq("/tux?range=week&repo=#{CGI.escape(progress_repo(0))}")
    expect(section.at_css("a[aria-label='Next period']")["href"]).to eq("/tux?range=month&repo=#{CGI.escape(progress_repo(0))}")
  end

  it "numbers a disc per listed entry's bucket, linked to its row" do
    get "/tux"

    discs = section.css("a[href^='#progress-note-']")
    expect(discs.map(&:text)).to eq(%w[1 2–3 4 5 6])
    expect(discs.first["aria-label"]).to eq("Note 1, shipped Mar 31: live on Hacker News")
  end

  it "shows a visitor the owner's section, without Make a card and the tag line" do
    get "/tux"
    visitor = section.text.squish

    sign_in_as(user)
    get "/tux"
    owner = section
    owner.at_css("[data-controller='dialog']").remove
    expect(owner.text.squish).to eq("#{visitor} 19 entries in 2026 have no project. Tag them")
  end

  it "switches to the Lines chart, keeping the period" do
    get "/tux", params: { range: "month", chart: "lines" }

    expect(section.at_css("svg[role='img']")["aria-label"]).to eq("Commits added up per project, October 2026")
    expect(section.at_css("nav[aria-label='Chart'] a[aria-current='page']").text.squish).to eq("Lines")
    bars = section.css("nav[aria-label='Chart'] a").find { |a| a.text.squish == "Bars" }
    expect(bars["href"]).to eq("/tux?range=month")
  end

  it "shows several projects at once, and the timeline follows them" do
    create(:entry, user: user, repo_name: progress_repo(1), title: "A wheels-off commit", occurred_at: 1.hour.ago)
    create(:entry, user: user, repo_name: progress_repo(2), title: "A goal_atlas commit", occurred_at: 1.hour.ago)
    get "/tux", params: { repo: [ progress_repo(0), progress_repo(1) ] }

    expect(section.at_css("h2").parent.text.squish).to include("2026 openstage + wheels-off")
    expect(section.text.squish).to include("239 Commits", "Share of commits")
    expect(section.css("input[name='repo[]'][checked]").map { |box| box["value"] }).to eq([ progress_repo(0), progress_repo(1) ])
    timeline = Nokogiri::HTML(response.body).at_css("turbo-frame#timeline").text
    expect(timeline).to include("A wheels-off commit")
    expect(timeline).not_to include("A goal_atlas commit")
    expect(Nokogiri::HTML(response.body).at_css("turbo-frame#progress_card")).to be_nil
  end
end
