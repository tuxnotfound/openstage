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
