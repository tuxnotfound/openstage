require "rails_helper"

RSpec.describe Analytics::ForgetVisitorsService do
  let(:user) { create(:user, rolled_up_to: Time.utc(2026, 10, 25, 7)) }

  before { travel_to Time.utc(2026, 10, 26, 3) }

  it "deletes the hashes of days over everywhere, and keeps the views" do
    old = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 23, 59), ip_hash: "a")
    behind = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 25, 0, 1), ip_hash: "b")
    project = user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 24, 20), ip_hash: "c")

    service = described_class.new.tap(&:call!)

    expect(service.forgotten).to eq(2)
    expect([ old.reload.ip_hash, behind.reload.ip_hash, project.reload.ip_hash ]).to eq([ nil, "b", nil ])
  end

  it "keeps a hash the rollup has not counted" do
    user.update!(rolled_up_to: Time.utc(2026, 10, 24, 7))
    counted = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 6), ip_hash: "a")
    waiting = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 8), ip_hash: "b")
    never = create(:profile_view, user: create(:user), viewed_at: Time.utc(2026, 10, 1), ip_hash: "c")

    described_class.new.call!

    expect([ counted.reload.ip_hash, waiting.reload.ip_hash, never.reload.ip_hash ]).to eq([ nil, "b", "c" ])
  end

  it "runs from its daily job" do
    view = create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 1), ip_hash: "a")

    ForgetPageVisitorsJob.perform_now

    expect(view.reload.ip_hash).to be_nil
  end
end
