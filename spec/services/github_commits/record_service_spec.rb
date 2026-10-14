require "rails_helper"

RSpec.describe GithubCommits::RecordService do
  let(:user) { create(:user, github_username: "me") }
  let(:repo) { create(:github_repo, user: user, full_name: "me/app", private_repo: false) }
  let(:authored_at) { Time.utc(2026, 10, 12, 10) }

  def commit(sha, message: "Add search", login: "me", email: "me@example.com", at: authored_at)
    GithubGateway::Commit.new(sha: sha, message: message, authored_at: at, html_url: "https://github.com/me/app/commit/#{sha}",
                              author_login: login, author_email: email)
  end

  def record(commit, branch: nil)
    described_class.new(user: user, repo: repo, commit: commit, branch: branch, token: "tok").tap(&:call!)
  end

  def branch_entry(sha, branch: "feature", title: "Add search")
    create(:entry, user: user, source: "github", external_id: sha, title: title, occurred_at: authored_at,
                   repo_name: "me/app", branch: branch)
  end

  it "puts a default-branch commit on the page with no branch" do
    expect(record(commit("c1")).added).to be(true)

    expect(user.entries.sole).to have_attributes(external_id: "c1", title: "Add search", branch: nil, repo_name: "me/app",
                                                 occurred_at: authored_at, url: "https://github.com/me/app/commit/c1")
  end

  it "tags a commit read on another branch with that branch" do
    record(commit("c1"), branch: "feature/search")

    expect(user.entries.sole.branch).to eq("feature/search")
  end

  it "skips a commit someone else wrote" do
    expect(record(commit("c1", login: "teammate", email: "t@example.com")).added).to be(false)
    expect(user.entries).to be_empty
  end

  # GitHub ties no account to an email it has not verified.
  it "counts the builder's noreply address as theirs" do
    record(commit("c1", login: nil, email: "123+Me@users.noreply.github.com"))

    expect(user.entries.count).to eq(1)
  end

  it "never brings back a commit the builder deleted" do
    DismissedCommit.create!(user: user, sha: "c1")

    expect(record(commit("c1"), branch: "feature").added).to be(false)
    expect(user.entries).to be_empty
  end

  describe "a branch commit reaching the default branch" do
    it "drops the tag when the same commit arrives, as a merge commit or a fast-forward brings it" do
      entry = branch_entry("c1")

      expect(record(commit("c1")).added).to be(false)
      expect(entry.reload.branch).to be_nil
    end

    it "keeps the tag while the commit is read on its branch again" do
      entry = branch_entry("c1")

      record(commit("c1"), branch: "feature")

      expect(entry.reload.branch).to eq("feature")
    end

    it "follows a rebase merge to the new SHA, one entry and no tag" do
      entry = branch_entry("old")

      expect(record(commit("new")).added).to be(false)
      expect(user.entries.sole).to eq(entry)
      expect(entry.reload).to have_attributes(external_id: "new", branch: nil, url: "https://github.com/me/app/commit/new")
    end

    it "follows a rebase on the branch, keeping the branch" do
      entry = branch_entry("old")

      record(commit("new"), branch: "feature")

      expect(entry.reload).to have_attributes(external_id: "new", branch: "feature")
    end

    it "never takes over a default-branch commit with the same date and title" do
      create(:entry, user: user, source: "github", external_id: "main1", title: "Add search", occurred_at: authored_at,
                     repo_name: "me/app", branch: nil)

      record(commit("c2"), branch: "feature")

      expect(user.entries.pluck(:external_id)).to contain_exactly("main1", "c2")
    end
  end

  describe "a squash merge" do
    let(:squash) { commit("sq1", message: "Search (#12)\n\n* Add search\n* Fix search", at: Time.utc(2026, 10, 13)) }

    it "is left out when its pull request's commits are on the page, which lose their tag" do
      first = branch_entry("c1", title: "Add search")
      second = branch_entry("c2", title: "Fix search")
      allow(GithubGateway).to receive(:merged_pull_numbers).with("me/app", "sq1", token: "tok").and_return([ 12 ])
      allow(GithubGateway).to receive(:pull_commit_shas).with("me/app", 12, token: "tok").and_return(%w[c1 c2])

      expect(record(squash).added).to be(false)
      expect(user.entries.pluck(:external_id)).to contain_exactly("c1", "c2")
      expect([ first.reload.branch, second.reload.branch ]).to eq([ nil, nil ])
    end

    it "goes on the page when none of its pull request's commits are there" do
      branch_entry("other")
      allow(GithubGateway).to receive_messages(merged_pull_numbers: [ 12 ], pull_commit_shas: %w[c1 c2])

      expect(record(squash).added).to be(true)
    end

    # The GitHub App reads pull requests only once its owner accepts that permission.
    it "goes on the page when the token cannot read pull requests" do
      branch_entry("c1")
      allow(GithubGateway).to receive(:merged_pull_numbers).and_raise(ApplicationGateway::Unauthorized)

      expect(record(squash).added).to be(true)
    end

    it "costs no call while the repo has no branch commits on the page" do
      allow(GithubGateway).to receive(:merged_pull_numbers)

      record(squash)

      expect(GithubGateway).not_to have_received(:merged_pull_numbers)
    end
  end

  it "never links a private repo's commit" do
    repo.update!(private_repo: true)

    record(commit("c1"))

    expect(user.entries.sole.url).to be_nil
  end

  it "titles a commit without a message by its short SHA" do
    record(commit("abcdef123456", message: ""))

    expect(user.entries.sole.title).to eq("abcdef1")
  end
end
