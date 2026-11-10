require "rails_helper"

RSpec.describe "The button to make your own stage", type: :request do
  let(:user) { create(:user, username: "builder") }

  before { create(:entry, user: user, repo_name: "builder/app", title: "Ship it") }

  def button
    Nokogiri::HTML(response.body).at_css("footer [data-claim-cta]")
  end

  def pages
    %w[/builder /builder/app].map do |path|
      get path
      expect(response).to have_http_status(:ok)
      button
    end
  end

  it "ends a Free builder's stage and project pages for a visitor, tagged, beside Explore other builders" do
    pages.each do |each|
      expect(each.text.squish).to eq("Make your own stage")
      expect(each["class"]).to eq("os-btn2")
      expect(URI(each["href"]).query).to eq("ref=footer")
      expect(each.parent.text).to include("Explore other builders")
    end
    expect(response.body).to include("Sign in<span class=\"max-sm:hidden\"> with GitHub</span>")
  end

  it "is gone from a Pro builder's pages, but not from the owner's" do
    user.update!(pro: true)
    expect(pages).to eq([ nil, nil ])
    expect(response.body).to include("Explore other builders")

    user.update!(github_username: "tuxnotfound")
    expect(pages).to all(be_present)
  end

  it "never shows to the builder on their own pages" do
    user.update!(github_username: "tuxnotfound", pro: true)
    sign_in_as(user)

    expect(pages).to eq([ nil, nil ])
  end
end
