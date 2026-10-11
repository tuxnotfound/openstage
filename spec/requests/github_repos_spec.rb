require "rails_helper"
require "support/github_app"

RSpec.describe "GithubRepos", type: :request do
  let!(:user) { create(:user) }
  let!(:repo) { create(:github_repo, user: user, full_name: "user/myapp", included: true) }

  # The Settings frame: it checks GitHub, then renders the repos section.
  describe "GET /github_repos" do
    let(:frame) { { "Turbo-Frame" => "github_repos" } }

    it "requires sign-in" do
      get github_repos_path, headers: frame
      expect(response).to redirect_to(root_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "sends a plain visit to the Integrations tab" do
        get github_repos_path
        expect(response).to redirect_to(settings_path(tab: "integrations"))
      end

      it "renders the section from the database while the App is not registered" do
        get github_repos_path, headers: frame

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/<turbo-frame[^>]*id="github_repos"/)
        expect(response.body).to include(repo.name)
      end

      context "with the App registered" do
        include_context "with the GitHub App configured"

        it "shows a private repo picked on GitHub since the last sync" do
          user.update!(github_uid: "123", github_username: "me")
          allow(GithubAppGateway).to receive(:user_installation).with("me").and_return(id: 7, account_id: 123)
          allow(GithubAppGateway).to receive(:installation_repositories).with(7).and_return([
            GithubAppGateway::Repo.new(id: 99, name: "fresh-secret", full_name: "me/fresh-secret", description: nil,
                                       html_url: "https://github.com/me/fresh-secret", default_branch: "main", private: true)
          ])

          get github_repos_path, headers: frame

          expect(response.body).to include("fresh-secret")
          expect(response.body).to include("Private repos are connected, read-only")
          expect(response.body).not_to include(GithubReposController::REFRESH_FAILED)
        end

        it "says why when the check refuses, instead of blaming GitHub" do
          user.update!(github_uid: "123", github_username: "me")
          allow(GithubAppGateway).to receive(:user_installation).and_return(id: 9, account_id: 555)

          get github_repos_path, headers: frame

          expect(response.body).to include("Your GitHub username has changed since you signed in")
          expect(response.body).not_to include(GithubReposController::REFRESH_FAILED)
        end

        it "still renders, with a note, when the App credentials are wrong" do
          allow(GithubAppGateway).to receive(:user_installation).and_raise(GithubAppGateway::Misconfigured.new("bad key"))

          get github_repos_path, headers: frame

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(GithubReposController::REFRESH_FAILED)
        end

        it "still renders, with a note, when GitHub does not answer" do
          allow(GithubAppGateway).to receive(:user_installation).and_raise(ApplicationGateway::ConnectionFailed.new("timeout"))

          get github_repos_path, headers: frame

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("GitHub did not answer")
          expect(response.body).to include(repo.name)
        end
      end
    end
  end

  describe "PATCH /github_repos/:id" do
    context "when not signed in" do
      it "redirects to root" do
        patch github_repo_path(repo), params: { included: "false" }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      context "excluding a repo" do
        let!(:entry) { create(:entry, user: user, source: "github", repo_name: "user/myapp", hidden: false) }

        it "marks the repo as excluded" do
          patch github_repo_path(repo), params: { included: "false" }
          expect(repo.reload.included).to be false
        end

        it "hides all entries from that repo" do
          patch github_repo_path(repo), params: { included: "false" }
          expect(entry.reload.hidden).to be true
        end

        it "does not affect entries from other repos" do
          other = create(:entry, user: user, source: "github", repo_name: "user/otherapp", hidden: false)
          patch github_repo_path(repo), params: { included: "false" }
          expect(other.reload.hidden).to be false
        end
      end

      # A private repo just connected through the GitHub App has no commits
      # until a sync reads it, and the manual sync has a cooldown.
      context "including a repo that was never synced" do
        let!(:new_private) { create(:github_repo, user: user, full_name: "user/secret", private_repo: true, included: false) }

        it "syncs right away" do
          expect(GithubSyncJob).to receive(:perform_later).with(user.id).once

          patch github_repo_path(new_private), params: { included: "true" }
        end

        it "does not sync again for a repo already synced" do
          new_private.update!(last_synced_at: 1.hour.ago)
          expect(GithubSyncJob).not_to receive(:perform_later)

          patch github_repo_path(new_private), params: { included: "true" }
        end
      end

      context "re-including a repo" do
        let!(:excluded_repo) { create(:github_repo, user: user, full_name: "user/oldapp", included: false) }
        let!(:hidden_entry)  { create(:entry, user: user, source: "github", repo_name: "user/oldapp", hidden: true) }

        it "marks the repo as included" do
          patch github_repo_path(excluded_repo), params: { included: "true" }
          expect(excluded_repo.reload.included).to be true
        end

        it "restores hidden entries from that repo" do
          patch github_repo_path(excluded_repo), params: { included: "true" }
          expect(hidden_entry.reload.hidden).to be false
        end

        it "remembers that the user chose, so the sync never re-defaults it" do
          patch github_repo_path(excluded_repo), params: { included: "true" }
          expect(excluded_repo.reload.included_chosen).to be true
        end
      end
    end
  end
end
