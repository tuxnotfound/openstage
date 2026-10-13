require "rails_helper"

RSpec.describe WeekCards::ComposeService do
  let(:user) { create(:user, username: "tux") }
  let(:monday) { Date.new(2026, 10, 5) }
  let(:week_card) { WeekCard.new(user: user, week_start: monday) }

  def commit(title, repo, day, hour: 12, **attrs)
    create(:entry, user: user, source: "github", entry_type: "shipped", title: title, repo_name: repo,
                   occurred_at: (monday + day).in_time_zone.change(hour: hour), **attrs)
  end

  def logged(type, title, day, **attrs)
    create(:entry, user: user, source: "manual", entry_type: type, title: title,
                   occurred_at: (monday + day).in_time_zone.change(hour: 15), **attrs)
  end

  def compose
    described_class.new(week_card: week_card).tap(&:call!).card
  end

  it "counts each day's commits per project, busiest project first" do
    commit("Add arcade mode", "me/wheels-off", 1)
    commit("Add HUD", "me/wheels-off", 1)
    commit("Blog: the relaunch story", "me/openstage", 1)
    commit("More", "me/wheels-off", 2)

    card = compose
    tuesday = card.days[1]
    expect(tuesday.label).to eq("TUE 6")
    expect(tuesday.segments.map { |s| [ s.project, s.n, s.slot ] }).to eq([ [ "wheels-off", 2, 0 ], [ "openstage", 1, 1 ] ])
    expect(card.totals).to have_attributes(commits: 4, active_days: 2, projects: 2)
    expect(card.projects.map(&:name)).to eq(%w[wheels-off openstage])
  end

  it "leaves out a project the builder turned off, from the bars and the totals" do
    commit("A", "me/wheels-off", 1)
    commit("B", "me/openstage", 1)
    week_card.projects = { "openstage" => "0" }

    card = compose
    expect(card.days[1].segments.map(&:project)).to eq([ "wheels-off" ])
    expect(card.totals.commits).to eq(1)
    expect(card.projects.find { |p| p.name == "openstage" }.shown).to be(false)
  end

  it "never shows what the page does not: hidden, private or tooling entries" do
    commit("Excluded repo work", "me/secret", 1, hidden: true)
    commit("Private entry", "me/app", 1, visibility: :private_entry)
    commit("Merge pull request #3 from me/branch", "me/app", 1)

    expect(compose.totals.commits).to eq(0)
  end

  describe "the day's headline" do
    it "is the builder's own words first" do
      commit("Serve the game at playwheelsoff.com", "me/wheels-off", 3)
      logged("milestone", "Something else", 3)
      week_card.headlines = { "2026-10-08" => { "text" => "playwheelsoff.com is live", "kind" => "shipped" } }

      expect(compose.days[3].headline).to have_attributes(text: "playwheelsoff.com is live", kind: "shipped", source: :builder)
    end

    it "is then a milestone, ahead of a post" do
      logged("posted", "This week's build log:", 3, url: "https://x.com/tux404/status/1")
      logged("milestone", "Trained on me is live!!", 3, repo_name: "me/trained-on")

      expect(compose.days[3].headline).to have_attributes(text: "Trained on me is live!!", kind: "shipped", project: "trained-on")
    end

    it "names a post by where it went, not by its first line" do
      logged("posted", "This week's build log:", 4, url: "https://x.com/tux404/status/1")

      expect(compose.days[4].headline).to have_attributes(text: "Posted on X", kind: "published")
    end

    it "is otherwise a count, never a bare commit message" do
      3.times { |i| commit("fix #{i}", "me/wheels-off", 2) }

      headline = compose.days[2].headline
      expect(headline).to have_attributes(text: "3 commits in wheels-off", kind: "built", source: :count)
    end

    it "offers what was logged and committed as starting points" do
      logged("milestone", "Trained on me is live!!", 3)
      commit("Space the page title below the menu line", "me/trained-on", 3)

      expect(compose.days[3].suggestions).to eq([ "Trained on me is live!!", "Space the page title below the menu line" ])
    end
  end

  it "says what the card leads with" do
    commit("Serve the game", "me/wheels-off", 3)
    week_card.headlines = { "2026-10-08" => { "text" => "playwheelsoff.com is live", "kind" => "shipped" } }

    expect(compose.lead).to have_attributes(date: monday + 3, text: "playwheelsoff.com is live", fly: "Shipped on Thursday, Oct 8")
  end

  it "names repos by their full name only when two share a short one" do
    commit("A", "ana/si2018-design", 1)
    commit("B", "dasilva/si2018-design", 1)
    commit("C", "me/openstage", 1)

    expect(compose.projects.map(&:name)).to contain_exactly("ana/si2018-design", "dasilva/si2018-design", "openstage")
  end

  it "finds the longest run of active days in the week" do
    [ 1, 2, 3, 4, 6 ].each { |day| commit("work", "me/app", day) }

    expect(compose.best_run).to eq(4)
  end

  it "drafts a post from the card's own facts, ending on next week's goal" do
    commit("A", "me/app", 1)
    logged("milestone", "Trained on me is live!!", 3)
    week_card.next_goal = "Launch on Product Hunt"

    expect(compose.draft).to eq("Week 41: 1 commit on 2 of 7 days.\n- Trained on me is live!!\nNext: Launch on Product Hunt")
  end

  it "counts days in the card's time zone" do
    # 23:30 on Sunday in Lisbon is already Monday in UTC.
    create(:entry, user: user, source: "github", entry_type: "shipped", title: "late", repo_name: "me/app",
                   occurred_at: Time.utc(2026, 10, 11, 22, 30))
    create(:entry, user: user, source: "github", entry_type: "shipped", title: "next week", repo_name: "me/app",
                   occurred_at: Time.utc(2026, 10, 11, 23, 30))
    week_card.time_zone = "Europe/Lisbon"

    card = compose
    expect(card.days.last.total).to eq(1)
    expect(card.totals.commits).to eq(1)
  end

  it "counts the week before the same way, for the change from last week" do
    commit("A", "me/app", 1)
    commit("B", "me/app", -6)
    commit("C", "me/hidden", -6)
    week_card.projects = { "hidden" => "0" }

    expect(compose.previous.totals).to have_attributes(commits: 1, active_days: 1)
  end

  it "uses the headlines written on last week's own card" do
    WeekCard.create!(user: user, week_start: monday - 7,
                     headlines: { "2026-09-29" => { "text" => "Shipped the blog", "kind" => "shipped" } })

    expect(compose.previous.totals.shipped).to eq(1)
  end

  it "shows the current streak only on the current week" do
    travel_to(monday + 20) { expect(compose.streak).to be_nil }
    travel_to(monday + 2) { expect(compose.streak).to eq(0) }
  end
end
