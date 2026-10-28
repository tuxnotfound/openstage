require "rails_helper"

RSpec.describe "Setting up a project's site visits", type: :request do
  let(:user) { create(:user, username: "builder", pro: true) }
  let!(:repo) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote", homepage: "https://shipnote.app") }

  before { sign_in_as(user) }

  def view
    get "/projects/#{repo.id}/edit", params: { site: "open" }
    Nokogiri::HTML(response.body).at_css("#site-visits")
  end

  it "picks Openstage's script and comes back with the line to paste" do
    patch "/projects/#{repo.id}/site_visits", params: { source: "script" }

    expect(response).to redirect_to(edit_project_path(repo, site: "open", anchor: "site-visits"))
    token = repo.reload.site_token
    expect(token).to start_with("os_")
    expect(view.at_css(".os-code").text).to eq(%(<script defer src="http://www.example.com/v.js" data-project="#{token}"></script>))
    expect(view.text).to include("Waiting for the first visit")
  end

  it "says when the first visit came, and counts the last 30 days" do
    travel_to Time.utc(2026, 10, 26, 14, 2)
    repo.update!(site_source: "script", site_token: "os_a", site_first_visit_at: Time.current)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 1204, visitors: 800)

    expect(view.text).to include("First visit received today at 14:02", "1,204", "Counted by Openstage's script on shipnote.app. Last visit less than a minute ago.")
  end

  it "hides them from the project's page with its switch, and turns them off" do
    repo.update!(site_source: "script", site_token: "os_a")

    patch "/projects/#{repo.id}/numbers", params: { number: "visits", shown: "false", back: "project" }
    expect(response).to redirect_to(edit_project_path(repo, anchor: "numbers"))
    expect(repo.reload.hidden_numbers).to eq([ "visits" ])
    expect(view.text).to include("Hidden")

    patch "/projects/#{repo.id}/site_visits", params: { source: "off" }
    expect(repo.reload).to have_attributes(site_source: nil, site_token: "os_a")
  end

  it "asks for a website first" do
    repo.update!(homepage: nil)

    patch "/projects/#{repo.id}/site_visits", params: { source: "script" }

    expect(flash[:alert]).to include("website first")
    expect(repo.reload.site_source).to be_nil
  end

  context "on Free" do
    let(:user) { create(:user, username: "builder", pro: false) }
    let!(:other) { create(:github_repo, user: user, name: "tidepool", homepage: "https://tidepool.dev", site_source: "script", site_token: "os_t") }

    it "counts one site: a second asks to count it instead, which turns the other off" do
      expect(view.text).to include("Free counts one site, and tidepool.dev counts now.", "Count this one instead")

      patch "/projects/#{repo.id}/site_visits", params: { source: "script" }
      expect(flash[:alert]).to include("Free counts one site")
      expect(repo.reload.site_source).to be_nil

      patch "/projects/#{repo.id}/site_visits", params: { source: "script", count_here: "1" }
      expect(repo.reload.site_source).to eq("script")
      expect(other.reload.site_source).to be_nil
      expect(view.text).to include("Free counts one site, and this is it.")
    end

    it "pauses the rest after a downgrade, counting the busiest" do
      repo.update!(site_source: "script", site_token: "os_s")
      other.site_visit_days.create!(day: Date.current, visits: 9, visitors: 3)

      expect(view.text).to include("Paused: Free counts one site, and tidepool.dev counts now.")
    end
  end

  it "never sets up someone else's project" do
    theirs = create(:github_repo, user: create(:user), homepage: "https://theirs.example")

    patch "/projects/#{theirs.id}/site_visits", params: { source: "script" }

    expect(response).to have_http_status(:not_found)
    expect(theirs.reload.site_source).to be_nil
  end
end
