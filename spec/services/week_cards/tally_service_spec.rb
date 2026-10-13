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

  it "needs a card" do
    expect(described_class.new(week_card: nil).call).to be(false)
  end
end
