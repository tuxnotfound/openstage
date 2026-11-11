require "rails_helper"

RSpec.describe Progress::ListService do
  let(:user) { create(:user) }

  before do
    travel_to Time.utc(2026, 11, 10, 12)
    # Ten projects with more commits than any below, so each takes a colour and a card.
    10.times { |i| commits("me/top#{i}", 5, 1.day.ago) }
  end

  def commits(repo, count, at)
    count.times { |i| create(:entry, user: user, repo_name: repo, occurred_at: at - i.minutes) }
  end

  def list(builder: nil, **listing)
    described_class.new(user: user, listing: Progress::Listing.new(**listing), builder: builder).tap(&:call!)
  end

  # A repo its builder hid from the stage, its commits hidden with it, as
  # GithubReposController hides them.
  def hidden(name, count, at)
    create(:github_repo, user: user, full_name: "me/#{name}", name: name, included: false)
    count.times { |i| create(:entry, user: user, repo_name: "me/#{name}", occurred_at: at - i.minutes, hidden: true) }
  end

  def names(service)
    service.cards.map(&:name)
  end

  it "lists the projects past the ten with a colour, latest commit first, each with its card" do
    commits("me/old", 1, 100.days.ago)
    commits("me/fresh", 1, 2.days.ago)
    commits("me/mid", 2, 10.days.ago)

    service = list

    expect(names(service)).to eq(%w[fresh mid old])
    expect([ service.count, service.found, service.page, service.pages ]).to eq([ 3, 3, 1, 1 ])
    expect(service.cards.map(&:commits)).to eq([ 1, 2, 1 ])
    expect(service.cards.first.last_commit).to eq(Date.new(2026, 11, 8))
  end

  it "sorts by commits over the cards' 52 weeks, then latest, or by name" do
    commits("me/ancient", 3, 2.years.ago)
    commits("me/fresh", 1, 2.days.ago)
    commits("me/mid", 2, 10.days.ago)
    commits("me/Alpha", 1, 50.days.ago)

    expect(names(list(sort: "commits"))).to eq(%w[mid fresh Alpha ancient])
    expect(names(list(sort: "name"))).to eq(%w[Alpha ancient fresh mid])
  end

  it "finds a project by its name, without regard to case, and keeps the live ones alone when asked" do
    create(:github_repo, user: user, full_name: "me/sauna-calc", homepage: "https://sauna.example")
    create(:github_repo, user: user, full_name: "me/sauna-notes", homepage: "")
    create(:github_repo, user: user, full_name: "me/fire", homepage: "https://fire.example")
    %w[me/sauna-calc me/sauna-notes me/fire].each { |repo| commits(repo, 1, 3.days.ago) }

    expect(names(list(query: "SAUNA"))).to eq(%w[sauna-calc sauna-notes])
    expect(names(list(live: true))).to eq(%w[fire sauna-calc])
    expect(names(list(query: "sauna", live: true))).to eq(%w[sauna-calc])
    expect(list(query: "sauna", live: true)).to have_attributes(count: 3, live_count: 2, found: 1)
    expect(list(query: "nothing")).to have_attributes(found: 0, page: 1, pages: 1, cards: [])
  end

  it "sorts a project whose builder hides its commits as if it had none, so its place gives nothing away" do
    create(:github_repo, user: user, full_name: "me/quiet", hidden_numbers: [ "commits" ])
    commits("me/quiet", 2, 1.hour.ago)
    commits("me/loud", 1, 30.days.ago)

    expect(names(list)).to eq(%w[loud quiet])
    expect(names(list(sort: "commits"))).to eq(%w[loud quiet])
    expect(list.cards.last.commits_shown?).to be(false)
  end

  it "shows 25 a page, and never a page past the last" do
    30.times { |i| commits(format("me/p%02d", i), 1, (i + 2).days.ago) }

    expect(names(list(page: 2))).to eq((25..29).map { |i| format("p%02d", i) })
    expect(list(page: 9)).to have_attributes(page: 2, pages: 2, found: 30)
    expect(list.cards.size).to eq(25)
  end

  it "reads the ranked projects itself, or takes the ones its caller ranked" do
    commits("me/fresh", 1, 2.days.ago)
    ranked = Progress::Projects.new(user.entries.counted_on_page, pinned: []).all

    given = described_class.new(user: user, listing: Progress::Listing.new, projects: ranked).tap(&:call!)

    expect(names(given)).to eq(names(list))
  end

  it "lists the projects hidden from the stage on the builder's dashboard when asked, with their commits as the builder sees them" do
    commits("me/shown", 1, 2.days.ago)
    hidden("quiet", 3, 5.days.ago)
    hidden("older", 1, 40.days.ago)

    stage = list(hidden: true)
    expect([ names(stage), stage.hidden, stage.hidden_count ]).to eq([ %w[shown], false, 0 ])

    dashboard = list(builder: true)
    expect([ names(dashboard), dashboard.hidden, dashboard.hidden_count, dashboard.count ]).to eq([ %w[shown], false, 2, 1 ])

    asked = list(builder: true, hidden: true, sort: "commits")
    expect([ names(asked), asked.cards.map(&:commits), asked.found ]).to eq([ %w[quiet older], [ 3, 1 ], 2 ])
  end

  it "lists the hidden ones on the dashboard while every other project has a colour" do
    hidden("quiet", 1, 5.days.ago)

    service = list(builder: true)

    expect([ service.count, service.hidden, names(service) ]).to eq([ 0, true, %w[quiet] ])
  end

  it "refuses without a builder or a listing" do
    expect(described_class.new(listing: Progress::Listing.new).call).to be(false)
    expect(described_class.new(user: user).call).to be(false)
  end
end
