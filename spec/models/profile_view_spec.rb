require "rails_helper"

RSpec.describe ProfileView, type: :model do
  let(:user) { create(:user) }

  describe ".daily_counts" do
    it "returns a hash with one key per day" do
      counts = ProfileView.daily_counts(days: 7)
      expect(counts.size).to eq(7)
    end

    it "counts views in the correct day bucket" do
      create(:profile_view, user: user, viewed_at: 2.days.ago)
      create(:profile_view, user: user, viewed_at: 2.days.ago)
      create(:profile_view, user: user, viewed_at: 1.day.ago)

      counts = user.profile_views.daily_counts(days: 7)
      two_days_ago = 2.days.ago.to_date.to_s
      one_day_ago  = 1.day.ago.to_date.to_s

      expect(counts[two_days_ago]).to eq(2)
      expect(counts[one_day_ago]).to  eq(1)
    end

    it "fills missing days with zero" do
      counts = user.profile_views.daily_counts(days: 7)
      expect(counts.values).to all(eq(0))
    end
  end

  describe ".unique_visitor_count" do
    it "counts distinct ip_hashes" do
      create(:profile_view, user: user, ip_hash: "aaa", viewed_at: 1.day.ago)
      create(:profile_view, user: user, ip_hash: "aaa", viewed_at: 2.hours.ago)
      create(:profile_view, user: user, ip_hash: "bbb", viewed_at: 3.hours.ago)

      expect(user.profile_views.unique_visitor_count(since: 7.days.ago)).to eq(2)
    end

    it "ignores views outside the window" do
      create(:profile_view, user: user, ip_hash: "ccc", viewed_at: 10.days.ago)

      expect(user.profile_views.unique_visitor_count(since: 7.days.ago)).to eq(0)
    end
  end

  describe ".top_countries" do
    it "returns countries sorted by count descending" do
      create(:profile_view, user: user, country: "US")
      create(:profile_view, user: user, country: "US")
      create(:profile_view, user: user, country: "GB")

      result = user.profile_views.top_countries
      expect(result.keys.first).to eq("US")
      expect(result["US"]).to eq(2)
    end

    it "ignores nil countries" do
      create(:profile_view, user: user, country: nil)
      expect(user.profile_views.top_countries).to be_empty
    end
  end
end
