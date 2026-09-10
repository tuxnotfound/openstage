require "rails_helper"

RSpec.describe RecapDraft do
  def item(type, title, repo = nil)
    described_class::Item.new(entry_type: type, title: title, repo_name: repo)
  end

  let(:busy_items) do
    [
      item("milestone", "Openstage rebirth begins"),
      item("shipped", "fix sync on default branch switch", "tuxnotfound/openstage"),
      item("shipped", "add overlap window to since", "tuxnotfound/openstage"),
      item("shipped", "derive final standings", "tuxnotfound/goal_atlas")
    ]
  end

  describe "quiet weeks" do
    it "refuses to build a post below the minimum" do
      draft = described_class.new(username: "tuxnotfound", items: [ item("shipped", "one commit", "a/b") ])

      expect(draft).to be_quiet
      expect(draft.text).to include("Quiet week")
      expect(draft.text).not_to include("commit)")
    end

    it "builds a post once there is enough material" do
      expect(described_class.new(username: "tuxnotfound", items: busy_items)).not_to be_quiet
    end
  end

  describe "structure" do
    subject(:draft) { described_class.new(username: "tuxnotfound", items: busy_items) }

    it "puts highlights above commits" do
      text = draft.text
      expect(text.index("Openstage rebirth begins")).to be < text.index("fix sync on default branch switch")
    end

    it "groups commits by short repo name with counts" do
      expect(draft.text).to include("openstage (2 commits)")
      expect(draft.text).to include("goal_atlas (1 commit)")
    end

    it "keeps the profile link out of the post body and offers it as a reply" do
      expect(draft.text).not_to include("openstage.dev")
      expect(draft.suggested_reply).to eq("Full timeline: https://openstage.dev/tuxnotfound")
    end

    it "stays plain: no emoji and no hashtags" do
      expect(draft.text).not_to match(/#\w+/)
      expect(draft.text).not_to match(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/)
    end
  end

  describe "volume limits" do
    it "truncates long commit lists per repo" do
      items = Array.new(9) { |i| item("shipped", "commit number #{i}", "me/app") }
      text = described_class.new(username: "me", items: items).text

      expect(text).to include("me/app".split("/").last + " (9 commits)")
      expect(text).to include("and 4 more")
    end

    it "summarises repos beyond the display cap" do
      items = Array.new(6) { |i| item("shipped", "a commit", "me/repo#{i}") }
      text = described_class.new(username: "me", items: items).text

      expect(text).to include("Plus smaller changes in 2 other repos.")
    end
  end

  describe "platform length budget" do
    let(:noisy_items) do
      Array.new(9) { |r| Array.new(6) { |c| item("shipped", "a reasonably wordy commit message #{r}-#{c}", "me/repo#{r}") } }.flatten
    end

    it "keeps a large week within the Bluesky limit" do
      draft = described_class.new(username: "me", items: noisy_items)

      expect(draft.text.length).to be <= 300
      expect(draft).to be_trimmed
    end

    it "respects a custom limit" do
      draft = described_class.new(username: "me", items: noisy_items, limit: 3000)

      expect(draft.text.length).to be <= 3000
      expect(draft.text.length).to be > 300
    end

    it "falls back to a counts summary when nothing else fits" do
      draft = described_class.new(username: "me", items: noisy_items, limit: 90)

      expect(draft.text.length).to be <= 120
      expect(draft.text).to match(/54 commits across 9 repos/)
    end

    it "does not mark a small week as trimmed" do
      expect(described_class.new(username: "me", items: busy_items)).not_to be_trimmed
    end
  end

  describe "diagnostics" do
    it "counts merge and dependency noise without removing it" do
      items = busy_items + [
        item("shipped", "Merge branch 'main' into feature", "a/b"),
        item("shipped", "bump rails from 7.1.5 to 7.1.6", "a/b")
      ]
      draft = described_class.new(username: "me", items: items)

      expect(draft.noisy_commit_count).to eq(2)
      expect(draft.text).to include("Merge branch 'main' into feature")
    end
  end

  describe "opening rotation" do
    it "varies the opening line across consecutive weeks" do
      openings = (0..2).map do |offset|
        described_class.new(
          username: "me", items: busy_items, period_end: Date.new(2026, 9, 10) + (offset * 7)
        ).text.lines.first
      end

      expect(openings.uniq.size).to eq(3)
    end
  end
end
