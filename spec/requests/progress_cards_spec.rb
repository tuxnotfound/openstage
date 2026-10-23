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

  it "offers the owner a card of the nearest calendar period, and never a visitor" do
    get "/tux", params: { range: "30d" }
    expect(page.at_css("turbo-frame#progress_card")).to be_nil

    sign_in_as(user)
    get "/tux", params: { range: "30d", repo: progress_repo(1) }
    expect(page.at_css("turbo-frame#progress_card")["src"]).to eq("/progress/card?range=month&repo%5B%5D=#{CGI.escape(progress_repo(1))}")
  end

  it "draws the owner's card with the post to go with it" do
    sign_in_as(user)
    get "/progress/card", params: { range: "month" }

    frame = page.at_css("turbo-frame#progress_card")
    expect(frame.at_css("svg[data-week-card='footnotes']")).to be_present
    expect(frame.at_css("[data-clipboard-target='source']").text).to eq(
      "October so far:\nTrained on me is live!!\nThis week's build log:\nWhat I worked on this week: 40 commits across 3 repos.\n" \
      "150 commits on 10 days."
    )
    expect(frame.at_css("[data-card-export-filename-value]")["data-card-export-filename-value"]).to eq("openstage-2026-10.png")
  end

  it "lists what the card left out, each with a Swap in that keeps the earlier swaps" do
    sign_in_as(user)
    get "/progress/card", params: { swap: "#{progress_entry(user, 8).id}" }

    swaps = page.css("a").select { |a| a.text == "Swap in" }
    expect(swaps.size).to eq(14)
    expect(swaps.first["href"]).to start_with("/progress/card?swap=#{progress_entry(user, 8).id}%2C")
    expect(page.at_css("[data-clipboard-target='source']").text).to include("Pro tier shipped 🎉")
  end

  it "builds each Swap in from the swaps still on the card, so a pushed-out one can come back" do
    sign_in_as(user)
    ids = [ 2, 5, 9, 11, 8 ].map { |id| progress_entry(user, id).id }
    get "/progress/card", params: { swap: ids.join(",") }

    day_one = page.css("li").find { |li| li.text.include?("day 1: it boots") }
    expect(day_one.at_css("a")["href"]).to eq("/progress/card?swap=#{(ids.drop(1) + ids.first(1)).join('%2C')}&theme=light")
  end

  it "switches the card between light and dark" do
    sign_in_as(user)
    get "/progress/card", params: { theme: "dark" }

    expect(page.at_css("svg[data-week-card] rect")["fill"]).to eq("#0E1012")
    expect(page.css("nav[aria-label='Card theme'] a").map { |a| a["href"] }).to eq([ "/progress/card?theme=light", "/progress/card?theme=dark" ])
  end

  it "warns under a filter that untagged entries are not on the card" do
    sign_in_as(user)
    get "/progress/card", params: { repo: progress_repo(4) }

    expect(page.text.squish).to include("19 entries in 2026 have no project and are not on this card. Tag them")
    expect(page.at_css("[data-clipboard-target='source']").text).to eq("trained-on, 2026 so far:\nTrained on me is live!!\n31 trained-on commits on 9 days.")
  end

  it "draws the card with lines for the Lines chart, with the same notes" do
    sign_in_as(user)
    get "/progress/card", params: { chart: "lines" }
    expect(page.css("svg[data-week-card='footnotes'] path[stroke-width='2.5']").size).to eq(7)
    expect(page.at_css("[data-clipboard-target='source']").text.lines.size).to eq(8)
    expect(page.css("nav[aria-label='Card theme'] a").first["href"]).to eq("/progress/card?chart=lines&theme=light")
  end

  it "makes a card of several projects, named together in the post" do
    sign_in_as(user)
    get "/progress/card", params: { repo: [ progress_repo(0), progress_repo(1) ] }

    draft = page.at_css("[data-clipboard-target='source']").text
    expect(draft.lines.first).to eq("openstage + wheels-off, 2026 so far:\n")
    expect(draft.lines.last).to eq("238 openstage + wheels-off commits on 39 days.")
    expect(page.css("nav[aria-label='Card theme'] a").first["href"]).to include("repo%5B%5D=#{CGI.escape(progress_repo(0))}")
  end

  it "reports a download and a copy with the card they came from" do
    sign_in_as(user)
    get "/progress/card", params: { chart: "lines" }

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
