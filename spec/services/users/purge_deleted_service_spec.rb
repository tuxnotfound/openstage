require "rails_helper"

RSpec.describe Users::PurgeDeletedService do
  it "deletes the accounts deleted more than 30 days ago, with what they own" do
    gone = create(:user, deleted_at: 31.days.ago)
    entry = create(:entry, user: gone)
    create(:entry_click, user: gone, entry: entry)
    repo = create(:github_repo, user: gone)
    repo.site_visit_days.create!(day: Date.current, visits: 1, visitors: 1)
    repo.site_visit_counts.create!(day: Date.current, kind: "country", value: "PT", count: 1)

    service = described_class.new
    expect(service.call).to be(true)

    expect(service.purged).to eq(1)
    expect(User.exists?(gone.id)).to be(false)
    expect(Entry.where(user_id: gone.id)).to be_empty
    expect(EntryClick.where(user_id: gone.id)).to be_empty
    expect(GithubRepo.where(user_id: gone.id)).to be_empty
    expect([ SiteVisitDay.count, SiteVisitCount.count ]).to eq([ 0, 0 ])
  end

  it "keeps accounts still inside the 30 days, and active ones" do
    recent = create(:user, deleted_at: 29.days.ago)
    active = create(:user)

    described_class.new.call!

    expect(User.where(id: [ recent.id, active.id ]).count).to eq(2)
  end
end
