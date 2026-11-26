require "rails_helper"

RSpec.describe Gates::Cohort do
  let(:today) { Date.new(2026, 11, 26) }
  let(:signed_up) { Time.utc(2026, 11, 13, 15, 1) }
  let(:builder) { create(:user, username: "builder", created_at: signed_up) }

  def row(users = User.where(id: builder.id))
    described_class.new(users, today: today).rows.first
  end

  it "dates a builder's second week from day 7 to day 13 after signup" do
    expect(row.first_day).to eq(Date.new(2026, 11, 20))
    expect(row.last_day).to eq(Date.new(2026, 11, 26))
  end

  it "reads the second week as ahead, open or closed" do
    ahead = create(:user, created_at: Time.utc(2026, 11, 24, 9))
    closed = create(:user, created_at: Time.utc(2026, 11, 10, 9))

    rows = described_class.new(User.where(id: [ builder.id, ahead.id, closed.id ]), today: today).rows

    expect(rows.map { |one| [ one.user.id, one.week ] }).to eq([ [ closed.id, :closed ], [ builder.id, :open ], [ ahead.id, :ahead ] ])
  end

  it "leaves a builder whose second week is ahead out of those old enough" do
    ahead = create(:user, created_at: Time.utc(2026, 11, 24, 9))

    cohort = described_class.new(User.where(id: [ builder.id, ahead.id ]), today: today)

    expect(cohort.old_enough.map(&:user)).to eq([ builder ])
  end

  it "keeps no one who did nothing in their second week" do
    Event.create!(user: builder, name: "seen", day: Date.new(2026, 11, 14))
    create(:profile_view, user: builder, viewed_at: Time.utc(2026, 11, 15))
    create(:badge_impression, user: builder, viewed_at: Time.utc(2026, 11, 19, 23, 59))

    expect(row).to have_attributes(came_back: false, views: 0, impressions: 0, retained?: false)
  end

  it "keeps a builder seen signed in on a day of their second week" do
    Event.create!(user: builder, name: "seen", day: Date.new(2026, 11, 20))

    expect(row).to have_attributes(came_back: true, retained?: true)
  end

  it "keeps a builder whose stage and project pages were seen twice by others in that week" do
    create(:profile_view, user: builder, viewed_at: Time.utc(2026, 11, 20, 0, 0))
    builder.project_views.create!(repo_name: "builder/app", viewed_at: Time.utc(2026, 11, 26, 23, 59))
    builder.project_views.create!(repo_name: "builder/app", viewed_at: Time.utc(2026, 11, 27, 0, 0))

    expect(row).to have_attributes(views: 2, seen?: true, retained?: true)
  end

  it "does not keep a builder seen once by others" do
    create(:profile_view, user: builder, viewed_at: Time.utc(2026, 11, 21))

    expect(row).to have_attributes(views: 1, seen?: false, retained?: false)
  end

  it "keeps a builder whose badge or embed was shown once in that week" do
    create(:badge_impression, user: builder, kind: "embed", viewed_at: Time.utc(2026, 11, 22))

    expect(row).to have_attributes(impressions: 1, shown?: true, retained?: true)
  end

  it "counts a project page's views that came from GitHub or from the builder's own sites" do
    create(:github_repo, user: builder, full_name: "builder/app", homepage: "https://app.example.com/start")
    builder.update!(website_url: "https://builder.dev")
    [ "github.com", "app.example.com", "builder.dev", "https://github.com/builder/app", "x.com", "notgithub.com", nil ].each do |referrer|
      builder.project_views.create!(repo_name: "builder/app", viewed_at: Time.utc(2026, 11, 14), referrer: referrer)
    end

    expect(row.outside).to eq(4)
  end

  it "does not count a view of the stage toward the project pages reached from outside" do
    create(:profile_view, user: builder, viewed_at: Time.utc(2026, 11, 14), referrer: "github.com")

    expect(row.outside).to eq(0)
  end

  it "counts the projects with site visits set up, and those that counted a visit" do
    create(:github_repo, user: builder, site_set_up_at: signed_up + 1.hour, site_first_visit_at: signed_up + 2.hours)
    create(:github_repo, user: builder, site_set_up_at: signed_up + 1.day)
    create(:github_repo, user: builder)

    expect(row).to have_attributes(sites: 2, counting: 1)
  end

  it "reads Stripe as connected while its key is not refused" do
    account = builder.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
    expect(row.stripe).to be(true)

    account.update!(refused_at: Time.current)
    expect(row.stripe).to be(false)
  end

  it "reads each builder's own numbers" do
    other = create(:user, created_at: signed_up + 1.minute)
    Event.create!(user: other, name: "seen", day: Date.new(2026, 11, 21))
    create(:badge_impression, user: builder, viewed_at: Time.utc(2026, 11, 22))

    rows = described_class.new(User.where(id: [ builder.id, other.id ]), today: today).rows

    expect(rows.map { |one| [ one.came_back, one.impressions ] }).to eq([ [ false, 1 ], [ true, 0 ] ])
  end
end
