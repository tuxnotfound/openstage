require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::PickService do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  def pick(range, offset: 0, cap: 6, repo: nil, swapped: [])
    tally = Progress::TallyService.new(user: user, range: range, offset: offset, repos: Array(repo)).tap(&:call!)
    described_class.new(items: tally.items, first_day: tally.first_active_day, last_day: tally.period.last_day,
                        cap: cap, swapped_ids: swapped).tap(&:call!)
  end

  def titles(items)
    items.map { |item| item.title.gsub(/\p{Extended_Pictographic}|\u{FE0F}/, "").squeeze(" ").strip }
  end

  it "keeps the design round's six for 2026, pins included, in date order" do
    expect(titles(pick("year").kept)).to eq([ "live on Hacker News", "story time is live!", "Share on 𝕏 !",
                                              "launched The Goal Atlas — just in time for 2026", "Rebirth begins",
                                              "Trained on me is live!!" ])
  end

  it "keeps the design round's eight for 2026 and all time at cap 8" do
    eight = [ "We are live!!", "live on Hacker News", "First user signed up", "story time is live!", "Share on 𝕏 !",
              "launched The Goal Atlas — just in time for 2026", "Rebirth begins", "Trained on me is live!!" ]

    expect(titles(pick("year", cap: 8).kept)).to eq(eight)
    expect(titles(pick("all", cap: 8).kept)).to eq(eight)
    expect(pick("year", cap: 8).left.map(&:kind).tally).to eq(shipped: 2, published: 10)
  end

  it "keeps all of October and September" do
    expect(pick("month").kept.size).to eq(3)
    expect(pick("month", offset: -1).kept.size).to eq(5)
  end

  it "drops only on picking rails from March" do
    march = pick("month", offset: -7)

    expect(march.kept.size).to eq(6)
    expect(titles(march.left)).to eq([ "on picking rails in 2026" ])
  end

  it "keeps nothing for a period with no entries" do
    expect(pick("week").kept).to be_empty
  end

  it "picks among tagged entries only under a filter" do
    expect(titles(pick("year", repo: progress_repo(4)).kept)).to eq([ "Trained on me is live!!" ])
    expect(pick("year", repo: progress_repo(0)).kept).to be_empty
  end

  it "ranks pins first, newest first" do
    expect(titles(pick("year").ranked.first(2))).to eq([ "Trained on me is live!!", "Rebirth begins" ])
  end

  describe "swapping in" do
    let(:pro_tier) { progress_entry(user, 8).id }
    let(:day_one) { progress_entry(user, 2).id }

    it "replaces the lowest-ranked unpinned entry" do
      swapped = pick("year", swapped: [ pro_tier ])

      expect(titles(swapped.kept)).to include("Pro tier shipped")
      expect(swapped.kept.size).to eq(6)
      expect(titles(swapped.left)).to include(titles(pick("year").ranked).last)
    end

    it "never undoes an earlier swap or pushes out a pin" do
      swapped = pick("year", swapped: [ pro_tier, day_one ])

      expect(titles(swapped.kept)).to include("Pro tier shipped", "day 1: it boots", "Rebirth begins", "Trained on me is live!!")
      expect(swapped.kept.size).to eq(6)
    end

    it "ignores an entry already kept or out of the period" do
      kept_id = pick("year").kept.first.id
      october_ids = pick("month").kept.map(&:id)

      expect(pick("year", swapped: [ kept_id ]).kept.map(&:id)).to eq(pick("year").kept.map(&:id))
      expect(pick("month", swapped: [ pro_tier ]).kept.map(&:id)).to eq(october_ids)
    end
  end
end
