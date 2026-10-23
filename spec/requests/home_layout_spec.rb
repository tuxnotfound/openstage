require "rails_helper"

# The landing had eight sections selling three products: a GitHub showcase (the
# comparison table), a post-writing tool (the recap section) and a network (the
# live feed). It now makes one argument in four sections.
RSpec.describe "Home layout", type: :request do
  let!(:demo) { create(:user, username: "tuxnotfound", display_name: "Tux") }

  before { create_list(:entry, 3, user: demo) }

  it "keeps the four agreed sections, in order" do
    get "/"

    order = [ "Keep shipping.", "How it works", "Frequently asked questions", "Your commits already tell the story." ]
    positions = order.map { |text| response.body.index(text) }

    expect(positions).to all(be_present)
    expect(positions).to eq(positions.sort)
  end

  it "drops the sections that framed it as something else" do
    get "/"

    expect(response.body).not_to include("Live public feed")
    expect(response.body).not_to include("Why Openstage")
    expect(response.body).not_to include("Everything on one page")
  end

  it "shows a real page above the fold, with a way to see all of it" do
    get "/"

    expect(response.body).to include("A real Openstage page")
    expect(response.body).to include("openstage.dev/tuxnotfound")
    expect(response.body).to include("See a live page")
  end

  it "sells projects: a line each, and what each one is" do
    get "/"

    expect(response.body).to include("Every project gets its line")
    expect(response.body).to include("What each project is")
  end

  # The recap picker is gone; Make a card is what a builder posts.
  it "sells Make a card, not the recap picker" do
    get "/"

    expect(response.body).to include("Make a card")
    expect(response.body).not_to match(/recap/i)
  end

  describe "demo card" do
    it "draws the page's last 12 months: the number, the chart and the latest shipped" do
      create(:entry, user: demo, entry_type: "milestone", source: "manual", title: "Rebirth begins", occurred_at: 3.weeks.ago)

      get "/"

      card = response.body[/<div class="os-card min-w-0 p-5">.*A real Openstage page/m]
      expect(card).to include("commits, last 12 months")
      expect(card).to include("os-chart")
      expect(card).to include("Rebirth begins")
      expect(card).to include(%(href="/tuxnotfound"))
    end

    # The page already leaves them out; the card showed "Merge pull request #5"
    # to Product Hunt visitors on 2026-10-20.
    it "counts merge and dependency-bump commits no more than the page does" do
      create(:entry, user: demo, title: "Merge pull request #5 from tuxnotfound/fix/weekly-email-body")
      create(:entry, user: demo, title: "Bump rack from 2.2.8 to 2.2.9")

      get "/"

      expect(response.body).to match(%r{<span class="os-num[^"]*">3</span>\s*<span[^>]*>commits, last 12 months})
      expect(response.body).not_to include("Merge pull request #5")
    end
  end

  it "renders the FAQ as native details so it collapses without JS" do
    get "/"
    expect(response.body).to include("<details")
    expect(response.body).to include("Frequently asked questions")
  end

  it "still serves the definition to crawlers via the FAQ and JSON-LD" do
    get "/"
    expect(response.body).to include("What is Openstage?")
    expect(response.body).to include("FAQPage")
  end

  it "degrades gracefully when the demo profile has no entries" do
    Entry.delete_all

    get "/"
    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("A real Openstage page")
  end
end
