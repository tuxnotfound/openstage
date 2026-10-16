require "rails_helper"

RSpec.describe WeekCards::HistoryService do
  let(:user) { create(:user) }
  let(:monday) { Date.new(2026, 10, 5) }
  let(:week_card) { WeekCard.new(user: user, week_start: monday, time_zone: "Europe/Lisbon") }

  def history
    described_class.new(week_card: week_card).tap(&:call!).history
  end

  def commits(n, at, **attributes)
    create_list(:entry, n, user: user, source: "github", entry_type: "shipped", repo_name: "me/app", occurred_at: at, **attributes)
  end

  def post(at)
    create(:entry, user: user, source: "manual", entry_type: "posted", title: "Posted", occurred_at: at)
  end

  it "counts the public commits before the week, and only those" do
    commits(3, Time.utc(2026, 9, 1, 12))
    commits(1, Time.utc(2026, 10, 4, 22, 30))
    commits(1, Time.utc(2026, 10, 4, 23, 30))
    commits(1, Time.utc(2026, 9, 2), visibility: :private_entry)
    commits(1, Time.utc(2026, 9, 2), title: "Merge pull request #12 from me/branch")
    post(Time.utc(2026, 9, 3))

    expect(history.commits_before).to eq(4)
  end

  it "finds the best week before this one, Monday to Monday in the card's zone" do
    commits(5, Time.utc(2026, 9, 21, 12))
    commits(3, Time.utc(2026, 9, 27, 22, 30))
    commits(4, Time.utc(2026, 9, 27, 23, 30))
    commits(9, Time.utc(2026, 10, 6, 12))

    expect(history.best_week).to eq(8)
  end

  it "has no best week before the first commit" do
    commits(9, Time.utc(2026, 10, 6, 12))

    expect(history.best_week).to be_nil
  end

  it "counts the quiet weeks right before this one, back to the last week with work" do
    post(Time.utc(2026, 9, 9, 12))
    commits(2, Time.utc(2026, 9, 1, 12))

    expect(history.quiet_weeks).to eq(3)
  end

  it "has no quiet weeks after an active one, nor before the builder's first entry" do
    expect(history.quiet_weeks).to eq(0)

    post(Time.utc(2026, 10, 2, 12))
    expect(history.quiet_weeks).to eq(0)
  end

  describe "the run of active days at the week's end" do
    it "counts back from Sunday across weeks" do
      (0..9).each { |back| commits(1, Time.utc(2026, 10, 11, 12) - back.days) }

      travel_to(Time.utc(2026, 10, 20)) { expect(history.streak).to eq(10) }
    end

    it "is nothing when Sunday was quiet" do
      commits(1, Time.utc(2026, 10, 10, 12))

      travel_to(Time.utc(2026, 10, 20)) { expect(history.streak).to eq(0) }
    end

    it "runs to today in the current week, or to yesterday while today is empty" do
      post(Time.utc(2026, 10, 6, 12))
      post(Time.utc(2026, 10, 7, 12))

      travel_to(Time.utc(2026, 10, 8, 9)) { expect(history.streak).to eq(2) }
      post(Time.utc(2026, 10, 8, 8))
      travel_to(Time.utc(2026, 10, 8, 9)) { expect(history.streak).to eq(3) }
    end
  end

  describe "the dust" do
    it "places each earlier commit at its weekday and hour in the card's zone" do
      commits(2, Time.utc(2026, 9, 29, 21, 30))
      commits(1, Time.utc(2026, 9, 29, 23, 30))

      expect(history.dust).to eq([ 2, 22 ] => 2, [ 3, 0 ] => 1)
      expect(history.since).to eq(Date.new(2026, 9, 29))
    end

    it "starts on the day the builder says they began building" do
      user.update!(building_since: Date.new(2026, 9, 1))
      commits(4, Time.utc(2026, 8, 20, 12))
      commits(1, Time.utc(2026, 9, 2, 12))

      expect(history).to have_attributes(since: Date.new(2026, 9, 1), commits_before: 5)
      expect(history.dust.values.sum).to eq(1)
    end

    it "is empty before the first commit" do
      expect(history).to have_attributes(since: nil, dust: {})
    end
  end

  it "needs a card" do
    expect(described_class.new(week_card: nil).call).to be(false)
  end
end
