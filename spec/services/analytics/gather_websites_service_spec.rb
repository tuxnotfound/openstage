require "rails_helper"

RSpec.describe Analytics::GatherWebsitesService do
  let(:user) { create(:user, pro: true) }
  let(:app) { create(:github_repo, user: user, site_source: "script", site_set_up_at: 10.days.ago) }
  let(:lib) { create(:github_repo, user: user) }
  let(:day) { Date.new(2026, 10, 20) }

  def count(repo, kind, value, count, on: day)
    repo.site_visit_counts.create!(kind: kind, value: value, count: count, day: on)
  end

  def gather(repos: [ app, lib ], days: day..(day + 6))
    described_class.new(user: user, repos: repos, days: days).tap(&:call!)
  end

  it "ranks eight of each kind, the busiest first, with what each leaves out: the rest and the cap's row" do
    10.times { |i| count(app, "country", "A#{(65 + i).chr}", 10 - i) }
    10.times { |i| count(lib, "page", "/p#{i}", 10 - i) }
    count(app, "page", SiteVisitCount::OTHER, 20)
    count(app, "source", "t.co", 1)
    count(lib, "source", "x.com", 1)

    service = gather
    expect(service.ranks["country"]).to eq(Analytics::Ranked.new(rows: (0..7).map { |i| [ "A#{(65 + i).chr}", 10 - i ] }, other: 2 + 1))
    expect(service.ranks["page"]).to eq(Analytics::Ranked.new(rows: (0..7).map { |i| [ "/p#{i}", 10 - i, lib.full_name ] }, other: 2 + 1 + 20))
    expect([ service.ranks["source"].rows, service.ranks["ref"], service.state ]).to eq([ [ [ "Twitter / X", 2 ] ], Analytics::Ranked.new(rows: [], other: 0), :shown ])
  end

  it "reads only the projects and the days asked for, every day for none" do
    count(app, "page", "/", 3)
    count(app, "page", "/old", 5, on: day - 30)
    count(lib, "page", "/lib", 1)

    expect(gather(repos: [ lib ]).ranks["page"].rows).to eq([ [ "/lib", 1, nil ] ])
    expect(gather(repos: user.github_repos, days: nil).ranks["page"].rows).to eq([ [ "/old", 5, app.full_name ], [ "/", 3, app.full_name ], [ "/lib", 1, lib.full_name ] ])
  end

  it "says why it has nothing: none of the projects counts site visits, or none came in those days" do
    count(app, "page", "/", 3, on: day - 30)

    expect(gather.state).to eq(:quiet)
    expect(gather(repos: user.github_repos).state).to eq(:quiet)
    expect(gather(repos: [ lib ]).state).to eq(:off)
    expect(gather(repos: []).state).to eq(:off)
    app.update!(site_source: nil)
    expect(gather(repos: user.github_repos).state).to eq(:off)
  end

  it "refuses without a builder" do
    expect(described_class.new(repos: [], days: nil).call).to be(false)
  end
end
