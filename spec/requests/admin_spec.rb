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
    end
  end
end
