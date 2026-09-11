require "rails_helper"

# The landing page had an infinite-scrolling feed sitting between the comparison
# table and the closing CTA, which made everything below it unreachable.
RSpec.describe "Home layout", type: :request do
  let!(:demo) { create(:user, username: "tuxnotfound", display_name: "Tux") }

  before { create_list(:entry, 3, user: demo) }

  it "puts the closing CTA above the feed so it can actually be reached" do
    get "/"

    cta  = response.body.index("Start your timeline")
    feed = response.body.index("Live public feed")

    expect(cta).to be_present
    expect(feed).to be_present
    expect(cta).to be < feed
  end

  it "caps the feed and sends the river to /feed instead of scrolling forever" do
    create_list(:entry, 12, user: demo)

    get "/"
    expect(response.body).to include("See all activity →")
    expect(response.body).not_to include("infinite-scroll")
  end

  it "shows a real profile above the fold" do
    get "/"

    expect(response.body).to include("A real Openstage page")
    expect(response.body).to include("openstage.dev/tuxnotfound")
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
