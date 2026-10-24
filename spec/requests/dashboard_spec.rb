require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to root" do
        get "/dashboard"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user, username: "builder") }

      before { sign_in_as(user) }

      it "shows the badge as an onboarding step, not the Settings snippet block" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("README badge")
        expect(response.body).to include("data-badge-nudge")
      end

      it "keeps sync status and Sync now beside the projects, and no page card" do
        get "/dashboard"

        sync = Nokogiri::HTML(response.body).at_css("[data-sync-status]")
        expect(sync.text.squish).to include("Not synced from GitHub yet", "Sync now")
        expect(response.body).not_to include("data-page-card", "Copy link")
      end

      it "offers to reconnect GitHub instead of syncing once GitHub turned the token down" do
        create(:sync_log, user: user, status: "failed", error_message: SyncLog::TOKEN_REJECTED)

        get "/dashboard"

        sync = Nokogiri::HTML(response.body).at_css("[data-sync-status]").to_html
        expect(sync).to include("Reconnect GitHub", "Reconnect GitHub to resume syncing.")
        expect(sync).not_to include("Sync now")
      end

      it "points a quiet week at the composer" do
        get "/dashboard"

        expect(response.body).to include("Quiet week so far.")
        expect(response.body).to include("Log an update")
        expect(response.body).not_to include("data-recap-prompt")
      end

      it "sums up a week with something to say, with no card to make" do
        3.times do |i|
          create(:entry, user: user, repo_name: "#{user.github_username}/app", title: "Step #{i}",
                         external_id: "sha-step-#{i}", occurred_at: 1.day.ago)
        end

        get "/dashboard"

        week = Nokogiri::HTML(response.body).at_css("[data-recap-prompt]")
        expect(week.text.squish).to include("You shipped 3 commits in app")
        expect(week.at_css("a")).to be_nil
      end

      it "names each line of the chart under it" do
        %w[app tool].each_with_index do |repo, i|
          create(:entry, user: user, repo_name: "#{user.github_username}/#{repo}", external_id: "sha-#{repo}", occurred_at: (i + 1).days.ago)
        end

        get "/dashboard"

        legend = Nokogiri::HTML(response.body).at_css("ul[aria-label=Lines]")
        expect(legend.css("li").map { |line| line.text.squish }).to contain_exactly("app", "tool")
      end

      it "drops the stat tiles that had no action attached" do
        get "/dashboard"

        expect(response.body).not_to include("Total entries")
        expect(response.body).not_to include("Manual posts")
      end
    end
  end

  # The app's tabs, as the revamp drafts drew them, plus an account menu
  # behind the avatar for the rest.
  describe "signed-in nav" do
    let(:user) { create(:user, username: "builder") }

    before { sign_in_as(user) }

    it "has the tabs, marks the one shown, and tucks the rest into a menu" do
      get "/dashboard"

      nav = response.body[/<nav class="os-nav.*?<\/nav>/m]
      expect(nav).to include(">Dashboard<", "Your page ", ">Settings<")
      expect(nav).not_to include("Week card")
      expect(nav).to include(%(<a aria-current="page" href="/dashboard">Dashboard</a>))

      menu = response.body[/<details.*?<\/details>/m]
      expect(menu).to include(">Explore builders<", ">Upgrade to Pro<", "Sign out")
      expect(menu).not_to include(">Admin<")
    end

    it "shows Analytics as a tab to Pro builders only" do
      get "/dashboard"
      expect(response.body).not_to include(">Analytics<")

      user.update!(pro: true)
      get "/dashboard"
      expect(response.body).to include(">Analytics<")
      expect(response.body).not_to include(">Upgrade to Pro<")
    end

    it "keeps the Dashboard tab lit on an entry's edit form" do
      entry = create(:entry, user: user)

      get "/entries/#{entry.id}/edit"

      expect(response.body).to include(%(<a aria-current="page" href="/dashboard">Dashboard</a>))
    end

    it "lights Your page on the builder's own page only" do
      create(:user, username: "someone")

      get "/builder"
      expect(response.body).to include(%(<a aria-current="page" href="/builder">))

      get "/someone"
      expect(response.body[/<nav class="os-nav.*?<\/nav>/m]).not_to include('aria-current="page"')
    end
  end
end
