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

  it "offers the owner a card of the period in view, and never a visitor" do
    get "/tux", params: { range: "month" }
    expect(page.at_css("turbo-frame#progress_card")).to be_nil

    sign_in_as(user)
    get "/tux", params: { range: "month" }
    expect(page.at_css("turbo-frame#progress_card")["src"]).to eq("/progress/card?range=month")
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

  it "draws the Journey card for the Lines chart, its post from the flags it places" do
    sign_in_as(user)
    get "/tux", params: { chart: "lines" }
    expect(page.at_css("turbo-frame#progress_card")["src"]).to eq("/progress/card?chart=lines")

    get "/progress/card", params: { chart: "lines" }
    expect(page.at_css("svg[data-week-card='journey']")).to be_present
    expect(page.at_css("[data-clipboard-target='source']").text.lines.size).to eq(8)
    expect(page.text).to include("This card puts words only where the line has room for them")
    expect(page.css("nav[aria-label='Card theme'] a").first["href"]).to eq("/progress/card?chart=lines&theme=light")
  end

  it "sends a visitor to sign in" do
    get "/progress/card"

    expect(response).to redirect_to(root_path)
  end
end
