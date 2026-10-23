require "rails_helper"
require "support/progress_data"

RSpec.describe "Making a card from the progress section" do
  include ProgressData

  let(:user) { create(:user, username: "tux") }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def draft
    page.at_css("[data-clipboard-target='source']").text
  end

  it "offers the owner a card of the window and projects in view, and never a visitor" do
    get "/tux", params: { range: "30d" }
    expect(page.at_css("turbo-frame#progress_card")).to be_nil

    sign_in_as(user)
    get "/tux", params: { range: "30d", repo: progress_repo(1) }
    expect(page.at_css("turbo-frame#progress_card")["src"]).to eq("/progress/card?range=30d&repo%5B%5D=#{CGI.escape(progress_repo(1))}")
  end

  it "draws the owner's card of the window, with the post to go with it" do
    sign_in_as(user)
    get "/progress/card", params: { range: "30d" }

    card = page.at_css("turbo-frame#progress_card svg[data-week-card='progress']")
    lines = draft.lines.map(&:chomp)
    expect(lines.first).to eq("Last 30 days:")
    expect(lines.last).to match(/\A#{progress_commits((ProgressData::TODAY.to_date - 29)..ProgressData::TODAY.to_date)} commits on \d+ days\.\z/)
    expect(lines[1..-2]).to all(satisfy { |title| card.text.include?(title.split.first) })
    expect(page.at_css("[data-card-export-filename-value]")["data-card-export-filename-value"]).to eq("openstage-30d-2026-10-15.png")
  end

  it "lists what the card left out, each with a Swap in that keeps the earlier swaps" do
    sign_in_as(user)
    pro = progress_entry(user, 8)
    get "/progress/card", params: { swap: pro.id.to_s }

    swaps = page.css("a").select { |a| a.text == "Swap in" }
    expect(swaps.size).to be > 10
    expect(swaps).to all(satisfy { |a| a["href"].include?("swap=#{pro.id}%2C") })
    expect(draft).to include("Pro tier shipped 🎉")
  end

  it "switches the card between light and dark" do
    sign_in_as(user)
    get "/progress/card", params: { theme: "dark" }

    expect(page.at_css("svg[data-week-card] rect")["fill"]).to eq("#0E0F12")
    expect(page.css("nav[aria-label='Card theme'] a").map { |a| a["href"] }).to eq([ "/progress/card?range=12m&theme=light", "/progress/card?range=12m&theme=dark" ])
  end

  it "warns under a filter that untagged entries are not on the card" do
    sign_in_as(user)
    get "/progress/card", params: { repo: progress_repo(4) }

    expect(page.text.squish).to include("#{progress_untagged(Date.new(2025, 11, 1)..ProgressData::TODAY.to_date)} entries in the last 12 months " \
                                        "have no project and are not on this card. Tag them")
    expect(draft).to eq("trained-on, last 12 months:\nTrained on me is live!!\n31 trained-on commits on 9 days.")
  end

  it "draws the page's chart: a line per project with commits, and a disc beside each note" do
    sign_in_as(user)
    get "/progress/card"

    card = page.at_css("svg[data-week-card='progress']")
    notes = draft.lines.size - 2
    expect(card.css("polyline").size).to eq(7)
    expect(card.css("circle[r='15']").size).to eq(notes)
    expect(card.css("circle[r='12']").size).to eq(notes)
  end

  it "makes a card of several projects, named together in the post" do
    sign_in_as(user)
    get "/progress/card", params: { repo: [ progress_repo(0), progress_repo(1) ] }

    expect(draft.lines.first).to eq("openstage + wheels-off, last 12 months:\n")
    expect(draft.lines.last).to eq("238 openstage + wheels-off commits on 39 days.")
    expect(page.css("nav[aria-label='Card theme'] a").first["href"]).to include("repo%5B%5D=#{CGI.escape(progress_repo(0))}")
  end

  it "reports a download and a copy with the card they came from" do
    sign_in_as(user)
    get "/progress/card"

    box = page.at_css("[data-controller='card-export clipboard']")
    expect(box.to_h.slice("data-card-export-event-value", "data-card-export-detail-value", "data-clipboard-event-value",
                          "data-clipboard-detail-value", "data-clipboard-track-url-value"))
      .to eq("data-card-export-event-value" => "progress_card_downloaded", "data-card-export-detail-value" => "lines",
             "data-clipboard-event-value" => "progress_post_copied", "data-clipboard-detail-value" => "lines",
             "data-clipboard-track-url-value" => "/events")

    post "/events", params: { name: "progress_card_downloaded", detail: "lines" }, as: :json
    post "/events", params: { name: "progress_post_copied", detail: "elsewhere" }, as: :json
    expect(Event.where(user: user).where.not(name: "seen").pluck(:name, :detail))
      .to contain_exactly([ "progress_card_downloaded", "lines" ], [ "progress_post_copied", "" ])
  end

  it "sends a visitor to sign in" do
    get "/progress/card"

    expect(response).to redirect_to(root_path)
  end
end
