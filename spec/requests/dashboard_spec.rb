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

      it "leaves the chart, the table, the window, the badge's card and the week's bar to other pages" do
        create(:entry, user: user, repo_name: "#{user.github_username}/app", occurred_at: 1.day.ago)

        get "/dashboard"

        expect(response).to have_http_status(:success)
        page = Nokogiri::HTML(response.body)
        expect(page.css(".os-chart, [data-chart-table], [data-badge-nudge], [data-chart-step], .os-sharebar, #progress-props")).to be_empty
        expect(response.body).not_to include("README badge", "Last 30 days")
      end

      it "gives a new Free account's first screen two filled buttons: Post entry and Go Pro" do
        get "/dashboard"

        filled = Nokogiri::HTML(response.body).css("main .os-btn")
        expect(filled.map { |button| button["value"] || button.text.squish }.uniq).to eq([ "Post entry", "Go Pro for $7 a month" ])
        expect(Nokogiri::HTML(response.body).css(".dt-send .os-btn").size).to eq(1)
      end

      it "opens on Projects, with nothing selected, and on Entries when the address names it" do
        get "/dashboard"
        page = Nokogiri::HTML(response.body)
        expect(page.css(".dt-tabs [role='tab']").map { |tab| [ tab.text.squish, tab["aria-selected"] ] }).to eq([ [ "Projects 0", "true" ], [ "Entries 0", "false" ] ])
        expect(page.at_css("#panel-entries")["class"]).to include("hidden")
        expect(JSON.parse(page.at_css("#dashboard-projects-props").text)["open"]).to be_nil

        get "/dashboard", params: { tab: "entries" }
        page = Nokogiri::HTML(response.body)
        expect(page.at_css("#panel-projects")["class"]).to include("hidden")
        expect(page.at_css("#tab-entries")["aria-selected"]).to eq("true")
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
        expect(sync).to include("Reconnect GitHub")
        expect(sync).not_to include("Sync now")
        expect(Nokogiri::HTML(response.body).text).to include(SyncLog::TOKEN_REJECTED)
      end

      it "says a quiet week beside the entry box's title" do
        get "/dashboard"

        week = Nokogiri::HTML(response.body).at_css(".dt-box .dt-week")
        expect(week.text.squish).to eq("This week Quiet week so far. An update tells visitors what the commits don't.")
      end

      it "sums up a week with something to say beside the box's title, with its streak and no bar" do
        3.times do |i|
          create(:entry, user: user, repo_name: "#{user.github_username}/app", title: "Step #{i}",
                         external_id: "sha-step-#{i}", occurred_at: 1.day.ago)
        end
        allow_any_instance_of(User).to receive(:current_streak).and_return(17)

        get "/dashboard"

        week = Nokogiri::HTML(response.body).at_css(".dt-box .dt-week")
        expect(week.text.squish).to eq("This week You shipped 3 commits in app. You logged no updates yet. 17-day streak")
        expect(week.at_css("b").text).to eq("3 commits")
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
      expect(nav).to include(">Dashboard<", "Your stage ", ">Feed<", ">Settings<")
      expect(nav).not_to include("Week card")
      expect(nav).to include(%(<a aria-current="page" href="/dashboard">Dashboard</a>))

      menu = response.body[/<details.*?<\/details>/m]
      expect(menu).to include(">Upgrade to Pro<", "Sign out")
      expect(menu).not_to include(">Admin<", "Explore builders")
    end

    it "shows Analytics as a tab to every builder, Free opening three of its tabs" do
      get "/dashboard"
      expect(response.body).to include(">Analytics<")

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
