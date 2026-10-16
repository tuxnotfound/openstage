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
    expect(section.text).to include("Changes vs Sep 1–15", "+127")

    get "/tux", params: { range: "month", offset: -1 }
    expect(section.at_css("h2").text).to eq("September 2026")
    expect(section.css("ol li").size).to eq(5)
  end

  it "says so when a period has nothing logged" do
    get "/tux", params: { range: "week" }

    expect(section.text).to include("Nothing shipped or published this week yet.")
    expect(section.text.squish).to include("79 Commits")
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

  it "shows a visitor the same section the owner sees" do
    get "/tux"
    visitor = section.text.squish

    sign_in_as(user)
    get "/tux"
    expect(section.text.squish).to eq(visitor)
  end
end
