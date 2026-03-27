require "rails_helper"

RSpec.describe "GithubRepos", type: :request do
  let!(:user) { create(:user) }
  let!(:repo) { create(:github_repo, user: user, full_name: "user/myapp", included: true) }

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
      end
    end
  end
end
