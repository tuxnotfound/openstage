require "rails_helper"

RSpec.describe SiteVisits::RankService do
  let(:user) { create(:user, pro: true) }
  let(:app) { create(:github_repo, user: user) }
  let(:lib) { create(:github_repo, user: user) }
  let(:day) { Date.new(2026, 10, 20) }

  def count(repo, kind, value, count, on: day)
    repo.site_visit_counts.create!(kind: kind, value: value, count: count, day: on)
  end

  def rank(kind, repos: [ app, lib ], days: day..(day + 6), top: 6)
    described_class.new(repos: repos, days: days, kind: kind, top: top).tap(&:call!)
  end

  it "names sources as Openstage's own panel does, Openstage too, and any other host by itself, never Other" do
    count(app, "source", "news.ycombinator.com", 5)
    count(app, "source", "openstage.dev", 4)
    count(app, "source", SiteVisitCount::DIRECT, 3)
    count(lib, "source", "indiehackers.com", 2)
    count(lib, "source", "google.co.uk", 1)

    expect(rank("source").ranked).to eq([ [ "Hacker News", 5 ], [ "Openstage", 4 ], [ "Direct", 3 ], [ "indiehackers.com", 2 ], [ "Google", 1 ] ])
  end

  it "counts hosts of one name together before cutting the top" do
    count(app, "source", "t.co", 2)
    count(lib, "source", "x.com", 2)
    count(app, "source", "indiehackers.com", 3)
    count(app, "source", "dev.to", 1)

    expect(rank("source", top: 2).ranked).to eq([ [ "Twitter / X", 4 ], [ "indiehackers.com", 3 ] ])
  end

  it "gives what the list leaves out apart, for every kind: the values past the top and the cap's Other row" do
    count(app, "source", "github.com", 2)
    count(lib, "source", "dev.to", 1)
    count(app, "source", SiteVisitCount::OTHER, 7)
    count(app, "page", "/", 9)
    count(app, "page", "/a", 3)
    count(lib, "page", SiteVisitCount::OTHER, 4)
    count(app, "page", SiteVisitCount::OTHER, 1, on: day + 1)

    expect([ rank("source").ranked, rank("source").other ]).to eq([ [ [ "GitHub", 2 ], [ "Dev.to", 1 ] ], 7 ])
    expect([ rank("source", top: 1).ranked, rank("source", top: 1).other ]).to eq([ [ [ "GitHub", 2 ] ], 8 ])
    expect([ rank("page").ranked, rank("page").other ]).to eq([ [ [ "/", 9 ], [ "/a", 3 ] ], 5 ])
    expect([ rank("page", top: 1).ranked, rank("page", top: 1).other ]).to eq([ [ [ "/", 9 ] ], 8 ])
    expect([ rank("ref").ranked, rank("ref").other ]).to eq([ [], 0 ])
  end

  it "keeps the busiest pages, ref tags and countries, the busiest first, then by value" do
    { "/pricing" => 9, "/docs" => 4, "/" => 4, "/blog" => 1 }.each { |path, views| count(app, "page", path, views) }
    count(lib, "page", "/blog", 4)
    count(app, "ref", "hn", 3)
    count(lib, "ref", "newsletter", 1)
    count(app, "country", "PT", 2)
    count(lib, "country", "PT", 1)
    count(lib, "country", "US", 2)

    expect([ rank("page", top: 3).ranked, rank("page", top: 3).other ]).to eq([ [ [ "/pricing", 9 ], [ "/blog", 5 ], [ "/", 4 ] ], 4 ])
    expect(rank("ref").ranked).to eq([ [ "hn", 3 ], [ "newsletter", 1 ] ])
    expect(rank("country").ranked).to eq([ [ "PT", 3 ], [ "US", 2 ] ])
  end

  it "reads only the days and projects asked for, every day without days" do
    other = create(:github_repo)
    count(app, "page", "/", 1, on: day - 1)
    count(app, "page", "/", 2)
    count(lib, "page", "/", 4, on: day + 7)
    count(other, "page", "/", 8)

    expect(rank("page").ranked).to eq([ [ "/", 2 ] ])
    expect(rank("page", days: ..(day + 6)).ranked).to eq([ [ "/", 3 ] ])
    expect(rank("page", days: nil).ranked).to eq([ [ "/", 7 ] ])
    expect(rank("page", repos: user.github_repos, days: nil).ranked).to eq([ [ "/", 7 ] ])
    expect(rank("page", repos: []).ranked).to eq([])
  end

  it "reads each kind in one grouped query" do
    count(app, "page", "/", 1)
    statements = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }, "sql.active_record") do
      SiteVisitCount::KINDS.each { |kind| described_class.new(repos: [ app.id ], days: day..day, kind: kind, top: 6).call! }
    end

    expect(statements.size).to eq(4)
    expect(statements).to all(include("GROUP BY"))
  end

  it "refuses a kind it does not count, or no top" do
    expect(described_class.new(repos: [ app ], days: nil, kind: "browser", top: 6).call).to be(false)
    expect(described_class.new(repos: [ app ], days: nil, kind: "page", top: 0).call).to be(false)
    expect(described_class.new(repos: [ app ], days: nil, kind: "page").call).to be(false)
  end
end
