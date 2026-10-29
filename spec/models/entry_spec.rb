require "rails_helper"

RSpec.describe Entry, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    subject { build(:entry, user: user) }

    it { should belong_to(:user) }
    it { should validate_presence_of(:entry_type) }
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:occurred_at) }
  end

  describe "external_id uniqueness" do
    it "prevents duplicate entries for the same user and external_id" do
      create(:entry, user: user, external_id: "abc123")
      duplicate = build(:entry, user: user, external_id: "abc123")
      expect(duplicate).not_to be_valid
    end

    it "allows the same external_id for different users" do
      other_user = create(:user)
      create(:entry, user: user, external_id: "abc123")
      entry = build(:entry, user: other_user, external_id: "abc123")
      expect(entry).to be_valid
    end

    it "allows multiple entries with nil external_id for the same user" do
      create(:entry, user: user, external_id: nil)
      entry = build(:entry, user: user, external_id: nil)
      expect(entry).to be_valid
    end
  end

  describe "repo_name normalization" do
    it "nilifies a blank repo_name" do
      entry = create(:entry, user: user, repo_name: "   ")
      expect(entry.repo_name).to be_nil
    end

    it "strips and keeps a present repo_name" do
      entry = create(:entry, user: user, repo_name: "  user/repo  ")
      expect(entry.repo_name).to eq("user/repo")
    end
  end

  describe "scopes" do
    it "visible excludes hidden entries" do
      create(:entry, user: user, hidden: false)
      create(:entry, user: user, hidden: true)
      expect(Entry.visible.count).to eq(1)
    end

    it "chronological orders by occurred_at descending" do
      older = create(:entry, user: user, occurred_at: 2.days.ago)
      newer = create(:entry, user: user, occurred_at: 1.day.ago)
      expect(Entry.chronological.to_a).to eq([ newer, older ])
    end

    it "visible hides branch commits while their builder has branch commits off" do
      on_branch = create(:entry, user: user, branch: "feature")
      on_main = create(:entry, user: user)
      other_builder = create(:entry, branch: "feature")
      expect(Entry.visible).to contain_exactly(on_branch, on_main, other_builder)

      user.update!(branch_commits: false)
      expect(Entry.visible).to contain_exactly(on_main, other_builder)
      expect(Entry.publicly_visible).to contain_exactly(on_main, other_builder)
    end

    it "highlights count a logged Shipped entry but never a commit, also stored as shipped" do
      commit = create(:entry, user: user)
      logged = create(:entry, user: user, source: "manual")
      milestone = create(:entry, user: user, source: "manual", entry_type: "milestone")
      post = create(:entry, user: user, source: "manual", entry_type: "posted")
      create(:entry, user: user, entry_type: "repo_created")

      expect(Entry.highlights).to contain_exactly(logged, milestone, post)
      expect(Entry.commits).to contain_exactly(commit)
      expect([ commit, logged ].map { |entry| [ entry.commit?, entry.highlight? ] }).to eq([ [ true, false ], [ false, true ] ])
    end
  end

  describe ".without_hidden_commits" do
    it "leaves out the commits of a project whose builder hides them, and only that builder's, keeping its other entries" do
      create(:github_repo, user: user, full_name: "user/app", hidden_numbers: [ "commits" ])
      create(:github_repo, user: user, full_name: "user/site", hidden_numbers: [ "visits" ])
      create(:entry, user: user, repo_name: "user/app")
      launch = create(:entry, user: user, repo_name: "user/app", entry_type: "milestone", source: "manual")
      release = create(:entry, user: user, repo_name: "user/app", entry_type: "released")
      shown = create(:entry, user: user, repo_name: "user/site")
      unsynced = create(:entry, user: user, repo_name: "user/gone")
      untagged = create(:entry, user: user, repo_name: nil)
      teammate = create(:entry, repo_name: "user/app")

      expect(Entry.without_hidden_commits).to contain_exactly(launch, release, shown, unsynced, untagged, teammate)
      expect(Entry.where(user: user).without_hidden_commits.commits).to contain_exactly(shown, unsynced, untagged)
    end
  end

  describe ".repo_names" do
    it "lists each repo once, sorted, leaving out entries without one" do
      create_list(:entry, 2, user: user, repo_name: "user/zeta")
      create(:entry, user: user, repo_name: "user/alpha")
      create(:entry, user: user, repo_name: nil)

      expect(Entry.repo_names).to eq([ "user/alpha", "user/zeta" ])
    end
  end
end
