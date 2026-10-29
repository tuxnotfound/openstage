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
    expect(view.text).not_to include("one project only")
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

    expect(response).to redirect_to(edit_project_path(repo, site: "open"))
    expect(flash[:alert]).to include("website first")
    expect(repo.reload.site_source).to be_nil
  end

  context "on Free" do
    let(:user) { create(:user, username: "builder", pro: false) }
    let!(:other) do
      create(:github_repo, user: user, name: "tidepool", homepage: "https://tidepool.dev", site_source: "script", site_token: "os_t", site_set_up_at: 10.days.ago)
    end

    def state
      view.at_css(".os-row > .os-muted.whitespace-nowrap").text
    end

    it "sets up one project for life: any other is refused with the Pro prompt, and offers no setup" do
      expect(view.text.squish).to include("Free counts site visits for one project, tidepool.")
      expect(view.at_css("a[href='/pricing']").text).to eq("Go Pro")
      expect(view.at_css("#site-source, [data-toggle-target='trigger']")).to be_nil
      expect(state).to eq("Off")

      patch "/projects/#{repo.id}/site_visits", params: { source: "script" }
      expect(response).to redirect_to(edit_project_path(repo, site: "open"))
      expect(flash[:alert]).to eq("Free counts site visits for one project, tidepool. Go Pro to count them for every project.")
      expect(repo.reload).to have_attributes(site_source: nil, site_set_up_at: nil)
      expect(view.text).not_to include("Count this one instead")
    end

    it "says at setup, before the sources, that Free counts one project for life, with Pro a link away" do
      other.destroy!
      setup = view.at_css("#site-source")
      notice = setup.at_css("[data-free-notice]")

      expect(notice.text.squish).to eq("Free counts site visits for one project only, the first you set up. Go Pro to count them for every project.")
      expect(notice.at_css("a")["href"]).to eq("/pricing")
      expect(setup.element_children.first).to eq(notice)
      expect(setup.at_css("[role='group'][aria-label='Source']")).to be_present

      repo.update!(homepage: nil)
      expect(view.at_css("#site-source [data-free-notice]")).to be_present
    end

    it "keeps the slot with that project while its script is off, so it can count again" do
      other.update!(site_source: nil)
      get "/projects/#{other.id}/edit", params: { site: "open" }
      row = Nokogiri::HTML(response.body).at_css("#site-visits")
      expect(row.text.squish).to include("Not counted.", "Openstage's script")

      patch "/projects/#{other.id}/site_visits", params: { source: "script" }
      expect(other.reload.site_source).to eq("script")
      get "/projects/#{other.id}/edit"
      expect(response.body).to include("Free counts site visits for one project, and this is it.")
    end

    it "pauses a project set up on Pro after the one set up first, and keeps its totals" do
      repo.update!(site_source: "script", site_token: "os_s", site_set_up_at: 3.days.ago, site_first_visit_at: 3.days.ago)
      repo.site_visit_days.create!(day: Date.current, visits: 9, visitors: 3)

      expect(view.text.squish).to include("Site visits 9", "Free counts site visits for one project, tidepool. This project's visits are not counted, and its page shows none. The totals so far are kept.")
      expect(state).to eq("Paused")
      expect(view.at_css("a[href='/pricing']").text).to eq("Go Pro")
    end
  end

  it "never sets up someone else's project" do
    theirs = create(:github_repo, user: create(:user), homepage: "https://theirs.example")

    patch "/projects/#{theirs.id}/site_visits", params: { source: "script" }

    expect(response).to have_http_status(:not_found)
    expect(theirs.reload.site_source).to be_nil
  end
end
