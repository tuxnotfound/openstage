require "rails_helper"

RSpec.describe RecapDraft do
  def item(type, title, repo = nil, sha: nil, merge: false)
    described_class::Item.new(
      entry_type: type, title: title, repo_name: repo,
      sha: sha || "sha-#{title}-#{repo}", merge: merge
    )
  end

  let(:busy_items) do
    [
      item("milestone", "Openstage rebirth begins"),
      item("shipped", "fix sync on default branch switch", "tuxnotfound/openstage"),
      item("shipped", "add overlap window to since", "tuxnotfound/openstage"),
      item("shipped", "derive final standings", "tuxnotfound/goal_atlas"),
      item("shipped", "Merge branch 'main' into feature", "tuxnotfound/openstage"),
      item("shipped", "bump rails from 7.1.5 to 7.1.6", "tuxnotfound/openstage")
    ]
  end

  # The opening line rotates by calendar week, so the week is pinned; without
  # this the wording assertions below pass or fail depending on the date.
  let(:pinned_week) { Date.new(2026, 9, 10) }

  subject(:draft) { described_class.new(username: "tuxnotfound", items: busy_items, period_end: pinned_week) }

  describe "quiet weeks" do
    it "refuses to build a post below the minimum" do
      quiet = described_class.new(username: "me", items: [ item("shipped", "one commit", "a/b") ])

      expect(quiet).to be_quiet
      expect(quiet.text).to include("Quiet week")
    end

    it "stays quiet even when picks are supplied" do
      quiet = described_class.new(username: "me", items: [ item("shipped", "one commit", "a/b") ])

      expect(quiet.text([ 1, 2 ])).to include("Quiet week")
    end

    it "does not let hidden tooling commits count as material" do
      merges = Array.new(4) { |i| item("shipped", "Merge pull request ##{i} from a/b", "a/b") }

      expect(described_class.new(username: "me", items: merges)).to be_quiet
    end

    it "is not quiet when the user's own highlights carry the week" do
      notes = Array.new(3) { |i| item("note", "a decision I wrote up #{i}") }

      expect(described_class.new(username: "me", items: notes)).not_to be_quiet
    end
  end

  describe "the noise filter" do
    it "hides merge and dependency-bot commits" do
      [
        "Merge branch 'main' into feature", "Merge pull request #3 from a/b", "Merge tag 'v1.0'",
        "bump rails from 7.1.5 to 7.1.6", "build(deps): bump rack from 3.0 to 3.1",
        "chore(deps-dev): bump eslint", "Update dependency react to v19"
      ].each do |title|
        d = described_class.new(username: "me", items: [ item("shipped", title, "a/b") ])
        expect(d.all_candidates.first.noise).to be(true), "expected #{title.inspect} to be filtered"
      end
    end

    it "hides merge commits detected structurally, whatever the message says" do
      hand_written = item("shipped", "Merge latest published translations from master", "a/b", merge: true)

      expect(described_class.new(username: "me", items: [ hand_written ]).all_candidates.first.noise).to be(true)
    end

    it "keeps the user's own voice: reverts and hand-written version bumps" do
      [ "Revert the caching change that broke prod", "Bump version to 1.2.0", "wip" ].each do |title|
        d = described_class.new(username: "me", items: [ item("shipped", title, "a/b") ])
        expect(d.all_candidates.first.noise).to be(false), "expected #{title.inspect} to survive"
      end
    end
  end

  describe "candidate numbering" do
    it "is identical whether or not tooling commits are shown" do
      hidden = described_class.new(username: "me", items: busy_items)
      shown  = described_class.new(username: "me", items: busy_items, include_noise: true)

      hidden.candidates.each do |c|
        match = shown.candidates.find { |s| s.index == c.index }
        expect(match.title).to eq(c.title)
      end
      expect(shown.candidates.size).to eq(5)
      expect(hidden.candidates.size).to eq(3)
    end

    it "orders by busiest repo and never by importance" do
      items = busy_items + [ item("shipped", "wip", "tuxnotfound/openstage") ]
      titles = described_class.new(username: "me", items: items).candidates.map(&:title)

      expect(titles).to eq([
        "fix sync on default branch switch", "add overlap window to since", "wip", "derive final standings"
      ])
    end

    it "drops duplicate commits that arrive from forks" do
      dupes = [
        item("shipped", "one change", "owner/app", sha: "abc"),
        item("shipped", "one change", "forker/app", sha: "abc"),
        item("shipped", "another", "owner/app", sha: "def")
      ]

      expect(described_class.new(username: "me", items: dupes).candidates.size).to eq(2)
    end
  end

  describe "skeleton" do
    it "states counts and the user's own highlights, never a commit" do
      expect(draft.skeleton).to eq("This week's build log: 3 commits across 2 repos.\n- Openstage rebirth begins")
    end

    it "counts what the toggle shows" do
      shown = described_class.new(username: "me", items: busy_items, include_noise: true, period_end: pinned_week)

      expect(shown.skeleton).to start_with("This week's build log: 5 commits")
    end

    it "names the window honestly when it is not a week" do
      monthly = described_class.new(username: "me", items: busy_items, days: 30)

      expect(monthly.skeleton).to start_with("Last 30 days: 3 commits")
    end
  end

  describe "text with picks" do
    it "is just the skeleton when nothing is picked" do
      expect(draft.text).to eq(draft.skeleton)
    end

    it "ignores an index belonging to a hidden tooling commit" do
      # 3 and 4 are the merge and the dependency bump; they keep their numbers
      # but are not pickable while hidden.
      expect(draft.text([ 3, 4 ])).to eq(draft.skeleton)
    end

    it "renders picks in the order the user typed, ignoring unknown indexes" do
      expect(draft.text([ 5, 1, 99 ])).to eq(<<~POST.chomp)
        This week's build log: 3 commits across 2 repos.
        - Openstage rebirth begins

        goal_atlas
        - derive final standings

        openstage
        - fix sync on default branch switch
      POST
    end

    it "ignores a repeated pick" do
      expect(draft.text([ 1, 1 ]).scan("fix sync on default branch switch").size).to eq(1)
    end

    it "does not repeat the repo name when there is only one" do
      single = described_class.new(username: "me", items: busy_items.reject { |i| i.repo_name.to_s.include?("goal_atlas") })
      text   = single.text([ 1 ])

      expect(text).to include("in openstage.")
      expect(text.scan("openstage").size).to eq(1)
    end

    it "keeps the profile link out of the body and offers it as a reply" do
      expect(draft.text([ 1, 2, 3 ])).not_to match(%r{https?://|openstage\.dev})
      expect(draft.suggested_reply).to eq("Full timeline: https://openstage.dev/tuxnotfound?ref=recap")
    end

    it "stays plain: no emoji and no hashtags" do
      text = draft.text([ 1, 2, 3 ])
      expect(text).not_to match(/#\w+/)
      expect(text).not_to match(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/)
    end
  end

  describe "titles" do
    it "uses the first non-blank line and strips the squash-merge PR suffix" do
      messy = item("shipped", "\n  feat: add dotenv support (#3)  \n\nlonger body here", "a/b")

      expect(described_class.new(username: "me", items: [ messy ]).all_candidates.first.title)
        .to eq("feat: add dotenv support")
    end
  end

  describe "length counter" do
    it "reports remaining characters and never truncates" do
      long = Array.new(20) { |i| item("shipped", "a reasonably wordy commit message number #{i}", "me/app") }
      wide = described_class.new(username: "me", items: long)

      expect(wide.remaining).to eq(280 - wide.skeleton.length)
      expect(wide.remaining((1..20).to_a)).to be_negative
      expect(wide.text((1..20).to_a)).to include("a reasonably wordy commit message number 19")
    end

    it "respects a custom limit" do
      expect(described_class.new(username: "me", items: busy_items, limit: 3000, period_end: pinned_week).remaining).to eq(3000 - draft.skeleton.length)
    end
  end

  describe "opening rotation" do
    it "varies the opening line across consecutive weeks" do
      openings = (0..2).map do |offset|
        described_class.new(username: "me", items: busy_items, period_end: Date.new(2026, 9, 10) + (offset * 7))
                       .skeleton.lines.first
      end

      expect(openings.uniq.size).to eq(3)
    end
  end
end
