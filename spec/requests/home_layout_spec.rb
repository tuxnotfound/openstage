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

  it "shows a real profile above the fold, with a way to see all of it" do
    get "/"

    expect(response.body).to include("A real Openstage page")
    expect(response.body).to include("openstage.dev/tuxnotfound")
    expect(response.body).to include("See a live page")
  end

  it "says what commits can't, and where the page goes" do
    get "/"

    expect(response.body).to include("Add what commits can't say")
    expect(response.body).to include("Share one link")
  end

  # The picker offers 7, 30 and 90 days. "Once a week" read as the only window.
  it "does not sell the recap as weekly-only" do
    get "/"

    expect(response.body).to include("Recap a week or a month")
    expect(response.body).not_to match(/once a week|weekly/i)
  end

  it "links the live page once in text; the card itself is the other way in" do
    get "/"

    expect(response.body).not_to include("see the whole thing")
    expect(response.body).to include(%(aria-label="Open Tux&#39;s live Openstage page"))
  end

  describe "demo card" do
    it "shows an entry written by hand next to two commits, preferring a pinned one" do
      create(:entry, user: demo, entry_type: "milestone", source: "manual", title: "Newer milestone", occurred_at: 1.hour.ago)
      create(:entry, user: demo, entry_type: "milestone", source: "manual", title: "Rebirth begins", pinned: true, occurred_at: 3.weeks.ago)

      get "/"

      highlight = response.body[/<div[^>]*data-demo-highlight.*?<\/div>/m]
      expect(highlight).to include("Pinned milestone, written by hand")
      expect(highlight).to include("Rebirth begins")
      expect(response.body).not_to include("Newer milestone")
      expect(response.body.scan("Commit message").size).to eq(2)
    end

    it "falls back to three commits when nothing was written by hand" do
      get "/"

      expect(response.body).not_to include("data-demo-highlight")
      expect(response.body.scan("Commit message").size).to eq(3)
      expect(response.body).to include("kept current by its commits")
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
