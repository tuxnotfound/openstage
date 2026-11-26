require "rails_helper"

RSpec.describe "Admin", type: :request do
  let(:owner) { create(:user, github_username: "tuxnotfound", username: "tuxnotfound") }

  describe "GET /admin" do
    it "404s when signed out" do
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end

    it "404s for another signed-in user" do
      sign_in_as(create(:user, github_username: "someone_else"))
      get "/admin"
      expect(response).to have_http_status(:not_found)
    end

    context "as the owner" do
      before { sign_in_as(owner) }

      it "renders without dividing by zero when nobody has activated" do
        get "/admin"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("0% of signups")
      end

      it "shows the weekly email funnel, leaving the owner out" do
        builder = create(:user, weekly_email_sent_at: 2.days.ago)
        owner.update!(weekly_email_sent_at: 2.days.ago)
        builder.subscriptions.create!(email: "r@example.com", confirmed_at: 1.week.ago, digest_sent_at: 2.days.ago)
        owner.subscriptions.create!(email: "mine@example.com", confirmed_at: 1.week.ago, digest_sent_at: 2.days.ago)

        get "/admin"
        expect(response.body).to include('data-weekly-step="weekly_mailed" data-count="1"')
        expect(response.body).to include('data-weekly-step="digests_mailed" data-count="1"')
      end

      it "leaves test accounts out of every number" do
        tester = create(:user, username: "tester", signup_ref: "direct", created_at: 1.day.ago, internal: true,
                               weekly_email_sent_at: 1.day.ago)
        create(:entry, user: tester, repo_name: "shared/repo")
        create(:entry, user: owner, repo_name: "shared/repo")
        create(:user, username: "real", signup_ref: "recap", created_at: 1.day.ago)

        get "/admin"
        expect(response.body).not_to include('data-ref="direct"')
        expect(response.body).to include('data-ref="recap" data-count="1"')
        expect(response.body).to include("0 of 1")
        expect(response.body).to include('data-weekly-step="weekly_mailed" data-count="0"')
        expect(response.body).not_to include("shared/repo")
      end

      it "groups signups by first touch" do
        create(:user, username: "fromrecap", signup_ref: "recap", created_at: 2.days.ago)
        active = create(:user, username: "active", signup_ref: "recap", created_at: 3.days.ago)
        create(:entry, user: active)
        create(:user, username: "direct_one", signup_ref: "direct", created_at: 4.days.ago)

        get "/admin"
        expect(response.body).to include('data-ref="recap" data-count="2"')
        expect(response.body).to include('data-ref="direct" data-count="1"')
      end

      it "ignores signups outside the window" do
        create(:user, username: "ancient", signup_ref: "recap", created_at: 90.days.ago)

        get "/admin"
        expect(response.body).not_to include('data-ref="recap"')
      end

      it "counts visits from Reddit" do
        reset!
        get "/", params: { ref: "reddit" }, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" }
        reset!
        sign_in_as(owner)

        get "/admin"
        expect(response.body).to include('data-ref-visit="reddit" data-count="1"')
      end

      it "counts the sign-ins started, by first touch" do
        reset!
        browser = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" }
        get "/", params: { ref: "reddit" }, headers: browser
        2.times { post "/auth/github", headers: browser }
        reset!
        sign_in_as(owner)

        get "/admin"
        expect(response.body).to include('data-sign-in-start="reddit" data-count="2"')
      end

      it "counts the builders who opened analytics, each once per tab, leaving me and test accounts out" do
        builder = create(:user)
        other = create(:user)
        Event.track("analytics_opened", user: builder, detail: "overview")
        Event.track("analytics_opened", user: builder, detail: "mrr")
        travel_to(1.day.ago) { Event.track("analytics_opened", user: builder, detail: "overview") }
        travel_to(40.days.ago) { Event.track("analytics_opened", user: other, detail: "visits") }
        Event.track("analytics_opened", user: other, detail: "overview")
        [ owner, create(:user, internal: true) ].each { |each| Event.track("analytics_opened", user: each, detail: "commits") }

        get "/admin"
        expect(response.body).to include('data-analytics-tab="any" data-count="2"', 'data-analytics-tab="overview" data-count="2"',
                                         'data-analytics-tab="mrr" data-count="1"', 'data-analytics-tab="commits" data-count="0"',
                                         'data-analytics-tab="visits" data-count="0"', 'data-analytics-tab="openstage" data-count="0"')
      end

      it "labels rows that predate ref tagging rather than dropping them" do
        create(:user, username: "old_row", signup_ref: nil, created_at: 2.days.ago)

        get "/admin"
        expect(response.body).to include('data-ref="unattributed"')
      end

      it "refuses the test email while delivery is switched off" do
        owner.update!(email: "me@example.com")

        expect { post "/admin/test_email" }.not_to change { ActionMailer::Base.deliveries.count }
        expect(flash[:alert]).to match(/RESEND_API_KEY/)
      end

      it "refuses the test email when the owner has no address" do
        owner.update!(email: nil)

        post "/admin/test_email"
        expect(flash[:alert]).to match(/no email/i)
      end

      it "sends when a key is present" do
        owner.update!(email: "me@example.com")
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RESEND_API_KEY").and_return("re_test")

        expect { post "/admin/test_email" }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(flash[:notice]).to match(/me@example\.com/)
      end

      it "sends me both weekly emails" do
        owner.update!(email: "me@example.com")

        expect { post "/admin/test_weekly_email" }.to change { ActionMailer::Base.deliveries.count }.by(2)
        expect(response).to redirect_to(admin_path)
        expect(flash[:notice]).to match(/me@example\.com/)
      end

      it "refuses the weekly test when I have no address" do
        owner.update!(email: nil)

        expect { post "/admin/test_weekly_email" }.not_to change { ActionMailer::Base.deliveries.count }
        expect(flash[:alert]).to match(/no email/i)
      end

      it "says so when the weekly test cannot be delivered" do
        owner.update!(email: "me@example.com")
        allow(ActionMailer::Base).to receive(:perform_deliveries).and_return(false)

        post "/admin/test_weekly_email"
        expect(flash[:alert]).to match(/Delivery failed: MailDeliveryGuard::Error/)
      end

      it "404s the weekly test for a non-owner" do
        sign_in_as(create(:user, github_username: "someone_else"))
        post "/admin/test_weekly_email"
        expect(response).to have_http_status(:not_found)
      end

      it "404s the test email for a non-owner" do
        sign_in_as(create(:user, github_username: "someone_else"))
        post "/admin/test_email"
        expect(response).to have_http_status(:not_found)
      end

      it "surfaces repos that more than one builder commits to" do
        a = create(:user, username: "alice")
        b = create(:user, username: "bob")
        create(:entry, user: a, source: "github", repo_name: "sydney/flood-risk")
        create(:entry, user: b, source: "github", repo_name: "sydney/flood-risk")
        create(:entry, user: a, source: "github", repo_name: "alice/solo")

        get "/admin"

        expect(response.body).to include('data-shared-repo="sydney/flood-risk" data-builders="2"')
        expect(response.body).not_to include('data-shared-repo="alice/solo"')
      end

      it "says none yet when every repo has a single builder" do
        get "/admin"
        expect(response.body).to include("None yet.")
      end

      it "is reachable from the nav" do
        get "/dashboard"
        expect(response.body).to include('href="/admin"')
      end

      it "counts who was kept in their second week by each clause of the rule, leaving me out" do
        back = create(:user, username: "cameback", created_at: 10.days.ago)
        seen = create(:user, username: "seentwice", created_at: 10.days.ago)
        create(:user, username: "neither", created_at: 10.days.ago)
        create(:user, username: "tooyoung", created_at: 2.days.ago)
        owner.update!(created_at: 10.days.ago)
        Event.create!(user: back, name: "seen", day: 3.days.ago.to_date)
        Event.create!(user: owner, name: "seen", day: 3.days.ago.to_date)
        2.times { create(:profile_view, user: seen, viewed_at: 2.days.ago) }

        get "/admin"

        expect(response.body).to include('data-kept="any" data-count="2"', 'data-kept="came-back" data-count="1"',
                                         'data-kept="seen" data-count="1"', 'data-kept="shown" data-count="0"', "2 of 3 old enough")
      end

      it "lists each builder of the window with what the gates read" do
        builder = create(:user, username: "prjctimg", signup_ref: "preview", created_at: 10.days.ago)
        create(:github_repo, user: builder, site_set_up_at: 9.days.ago, site_first_visit_at: 8.days.ago)
        create(:badge_impression, user: builder, viewed_at: 2.days.ago)
        create(:user, username: "fresh", created_at: 1.day.ago)

        get "/admin"

        expect(response.body).to include('data-builder="prjctimg" data-week="open" data-retained="true"', "counting on 1",
                                         'data-builder="fresh" data-week="ahead" data-retained="false"',
                                         'data-set-up="sites" data-count="1"', 'data-set-up="counting" data-count="1"')
        expect(response.body).not_to include('data-builder="tuxnotfound"')
      end

      it "reads a wider window when asked, and 30 days for anything else" do
        create(:user, username: "earlier", signup_ref: "preview", created_at: 45.days.ago)

        get "/admin"
        expect(response.body).to include("Last 30 days")
        expect(response.body).not_to include('data-builder="earlier"')

        get "/admin", params: { days: 60 }
        expect(response.body).to include("Last 60 days", 'data-builder="earlier"')

        get "/admin", params: { days: 7 }
        expect(response.body).to include("Last 30 days")
      end

      it "draws a bar for a signup of today" do
        owner.update!(created_at: 3.days.ago)
        create(:user, username: "justnow", created_at: Time.current)

        get "/admin"

        expect(response.body).to include(%(title="#{Date.current}: 1 signup"))
      end
    end
  end
end
