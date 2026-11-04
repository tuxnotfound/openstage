require "rails_helper"

RSpec.describe Analytics::RollUpService do
  let(:user) { create(:user, time_zone: "America/Los_Angeles") }
  let(:day) { Date.new(2026, 10, 23) }

  # 05:00 on the 25th in Los Angeles.
  before { travel_to Time.utc(2026, 10, 25, 12) }

  def roll_up
    described_class.new(user: user).tap(&:call!)
    user.reload
  end

  it "adds the days that are over in the builder's zone, a visitor once a day, and leaves today raw" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 6), ip_hash: "a") # the 23rd there
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 23, 20), ip_hash: "a")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "b") # the 24th
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 8), ip_hash: "c") # today
    user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 24, 6), ip_hash: "a")

    roll_up

    expect(user.page_days.order(:day, :page).pluck(:page, :day, :views, :visitors)).to eq(
      [ [ "me/app", day, 1, 1 ], [ "page", day, 2, 1 ], [ "page", day + 1, 1, 1 ] ]
    )
    expect(user.rolled_up_to).to eq(Time.utc(2026, 10, 25, 7))
  end

  it "counts a view by source and country, with no referrer as direct and no country left out" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 23, 20), referrer: "x.com", country: "PT")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 23, 20), referrer: nil, country: "T1")
    user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 23, 20), country: nil, referrer: "x.com")

    roll_up

    expect(user.page_counts.order(:page, :kind, :value).pluck(:page, :kind, :value, :count)).to eq(
      [ [ "me/app", "source", "x.com", 1 ], [ "page", "country", "PT", 1 ], [ "page", "source", "(direct)", 1 ], [ "page", "source", "x.com", 1 ] ]
    )
  end

  it "counts buttons by project, the badge and embed by site, and clicks by entry" do
    entry = create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", url: "https://a.example")
    2.times { EntryClick.create!(user: user, entry: entry, clicked_at: Time.utc(2026, 10, 23, 20)) }
    user.project_clicks.create!(repo_name: "me/app", kind: "visit", clicked_at: Time.utc(2026, 10, 23, 20))
    user.badge_impressions.create!(kind: "badge", viewed_at: Time.utc(2026, 10, 23, 20), referrer: "github.com")
    user.badge_impressions.create!(kind: "embed", viewed_at: Time.utc(2026, 10, 23, 20))

    roll_up

    expect(user.page_counts.order(:kind).pluck(:page, :kind, :value, :count)).to eq(
      [ [ "page", "badge", "github.com", 1 ], [ "me/app", "button", "visit", 1 ], [ "page", "embed", "(direct)", 1 ] ]
    )
    expect(user.entry_click_days.pluck(:entry_id, :day, :clicks)).to eq([ [ entry.id, day, 2 ] ])
  end

  it "adds each row once however often it runs" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 23, 20), ip_hash: "a", referrer: "x.com")

    2.times { roll_up }
    travel 1.day
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 20), ip_hash: "b")
    roll_up

    expect(user.page_days.order(:day).pluck(:day, :views)).to eq([ [ day, 1 ], [ day + 2, 1 ] ])
    expect(user.page_counts.where(kind: "source", value: "x.com").pluck(:count)).to eq([ 1 ])
  end

  it "leaves a day just over for the next run, while its last views can still be saving" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 6, 59))
    travel_to Time.utc(2026, 10, 25, 7, 2)

    roll_up

    expect(user.page_days).to be_empty
    expect(user.rolled_up_to).to eq(Time.utc(2026, 10, 24, 7))
  end

  it "adds the rest of a day a move to another zone left open, and never goes back" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 2), ip_hash: "a") # the 24th in Los Angeles
    roll_up
    user.update!(time_zone: "Asia/Tokyo")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 8), ip_hash: "b") # the 25th in Tokyo

    roll_up
    expect([ user.page_days.count, user.rolled_up_to ]).to eq([ 1, Time.utc(2026, 10, 25, 7) ])

    travel 1.day
    roll_up
    expect(user.page_days.order(:day).pluck(:day, :views)).to eq([ [ day + 1, 1 ], [ day + 2, 1 ] ])
  end

  it "goes with the builder" do
    create(:profile_view, user: user, viewed_at: 3.days.ago, referrer: "x.com")
    roll_up

    expect { user.destroy! }.to change(PageDay, :count).by(-1).and change(PageCount, :count).by(-1)
  end

  it "runs for every builder from its nightly job, those deleted these 30 days too" do
    create(:profile_view, user: user, viewed_at: 3.days.ago)
    deleted = create(:user, deleted_at: 2.days.ago)
    create(:profile_view, user: deleted, viewed_at: 3.days.ago)

    expect { RollUpFanoutJob.perform_now }.to have_enqueued_job(RollUpJob).exactly(:twice)

    RollUpJob.perform_now(deleted.id)
    expect(deleted.page_days.count).to eq(1)
  end

  it "needs a builder" do
    expect(described_class.new.call).to be(false)
  end
end
