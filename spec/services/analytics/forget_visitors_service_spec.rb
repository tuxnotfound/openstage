require "rails_helper"

RSpec.describe Analytics::ForgetVisitorsService do
  let(:user) { create(:user) }

  before { travel_to Time.utc(2026, 10, 26, 3) }

  it "deletes the hashes of days over everywhere, and keeps the views" do
    old = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 23, 59), ip_hash: "a")
    behind = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 0, 1), ip_hash: "b")
    project = user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "c")

    service = described_class.new.tap(&:call!)

    expect(service.forgotten).to eq(2)
    expect([ old.reload.ip_hash, behind.reload.ip_hash, project.reload.ip_hash ]).to eq([ nil, "b", nil ])
  end

  it "gives a visitor one random id for the day, and another for another builder" do
    morning = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 6), ip_hash: "a")
    evening = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "a")
    someone = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "b")
    elsewhere = create(:profile_view, user: create(:user), viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "a")

    described_class.new.call!

    expect(morning.reload.visitor).to be_present.and eq(evening.reload.visitor)
    expect([ someone.reload.visitor, elsewhere.reload.visitor ]).to all(be_present)
    expect([ morning.visitor, someone.visitor, elsewhere.visitor ].uniq.size).to eq(3)
  end

  it "does not wait for the rollup" do
    view = create(:profile_view, user: create(:user, rolled_up_to: nil), viewed_at: Time.utc(2026, 10, 1), ip_hash: "a")

    described_class.new.call!

    expect(view.reload.ip_hash).to be_nil
  end

  it "runs from its daily job" do
    view = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 1), ip_hash: "a")

    ForgetPageVisitorsJob.perform_now

    expect(view.reload.ip_hash).to be_nil
  end
end
