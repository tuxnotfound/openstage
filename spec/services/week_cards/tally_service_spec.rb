require "rails_helper"

RSpec.describe WeekCards::TallyService do
  let(:user) { create(:user) }
  let(:monday) { Date.new(2026, 10, 5) }
  let(:week_card) { WeekCard.new(user: user, week_start: monday) }

  def commits(n, repo, day)
    create_list(:entry, n, user: user, source: "github", entry_type: "shipped", repo_name: repo,
                           occurred_at: (monday + day).in_time_zone.change(hour: 12))
  end

  def headline_on(day)
    described_class.new(week_card: week_card).tap(&:call!).tally.days[day].headline
  end

  describe "a day's count line" do
    it "counts the whole day, busiest project first" do
      commits(2, "me/openstage", 1)
      commits(4, "me/wheels-off", 1)

      expect(headline_on(1)).to have_attributes(text: "6 commits in wheels-off and openstage", project: "wheels-off", source: :count)
    end

    it "says commit for one" do
      commits(1, "me/openstage", 3)

      expect(headline_on(3).text).to eq("1 commit in openstage")
    end

    it "counts the projects past two" do
      commits(9, "me/openstage", 2)
      commits(5, "me/wheels-off", 2)
      commits(2, "me/dotfiles", 2)

      expect(headline_on(2).text).to eq("16 commits in 3 projects")
    end

    it "leaves out the projects the builder turned off" do
      commits(4, "me/wheels-off", 1)
      commits(2, "me/openstage", 1)
      week_card.projects = { "openstage" => "0" }

      expect(headline_on(1).text).to eq("4 commits in wheels-off")
    end
  end

  describe "when the work happened" do
    def tally
      described_class.new(week_card: week_card).tap(&:call!).tally
    end

    def commit_at(repo, time)
      create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: repo, occurred_at: time)
    end

    before { week_card.time_zone = "Europe/Lisbon" }

    it "counts each day's commits by hour and project, in the card's zone" do
      commit_at("me/openstage", Time.utc(2026, 10, 6, 18, 30))
      commit_at("me/openstage", Time.utc(2026, 10, 6, 18, 50))
      commit_at("me/wheels-off", Time.utc(2026, 10, 6, 18, 10))
      commit_at("me/wheels-off", Time.utc(2026, 10, 6, 23, 30))

      expect(tally.days[1].hours).to eq(19 => { "openstage" => 2, "wheels-off" => 1 })
      expect(tally.days[2].hours).to eq(0 => { "wheels-off" => 1 })
    end

    it "keeps each launch and post the builder logged, at its local time" do
      create(:entry, user: user, source: "manual", entry_type: "milestone", title: "playwheelsoff.com is live",
                     occurred_at: Time.utc(2026, 10, 8, 16))
      create(:entry, user: user, source: "manual", entry_type: "posted", title: "Week 41", url: "https://x.com/tux404/status/1",
                     occurred_at: Time.utc(2026, 10, 9, 15, 5))

      expect(tally.days[3].launches.map { |log| [ log.title, log.at.hour ] }).to eq([ [ "playwheelsoff.com is live", 17 ] ])
      expect(tally.days[4].posts.first).to have_attributes(url: "https://x.com/tux404/status/1")
      expect(tally.days[4].posts.first.at.strftime("%H:%M")).to eq("16:05")
      expect(tally.totals).to have_attributes(launches: 1, posts: 1)
    end

    it "starts the week's peak at its busiest two hours" do
      [ 18, 18, 19, 19, 20, 20, 20 ].each { |hour| commit_at("me/app", Time.utc(2026, 10, 7, hour)) }

      expect(tally.totals.peak_hour).to eq(20)
    end

    it "has no peak without commits" do
      expect(tally.totals.peak_hour).to be_nil
    end
  end

  it "needs a card" do
    expect(described_class.new(week_card: nil).call).to be(false)
  end
end
