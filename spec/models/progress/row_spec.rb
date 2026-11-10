require "rails_helper"

RSpec.describe Progress::Row do
  it "says which numbers it counts and which of them it shows" do
    row = described_class.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: nil, on: true, counted: %w[commits visits], shown: %w[commits])

    expect([ row.counts?("visits"), row.shows?("visits"), row.shows?("commits"), row.counts?("views") ]).to eq([ true, false, true, false ])
  end

  it "has a box while it has a colour, and the chart draws it while it is in view too" do
    row = ->(color_class, on) { described_class.new(key: "me/app", name: "app", rank: 0, color_class: color_class, repo: nil, on: on, counted: [], shown: []) }

    expect([ row.call("os-project-1", true), row.call("os-project-1", false), row.call(nil, true) ].map { |each| [ each.boxed?, each.drawn? ] })
      .to eq([ [ true, true ], [ true, false ], [ false, false ] ])
  end

  it "never shows a number that sits beside one it does not show, which its builder's table still lists" do
    row = ->(shown) { described_class.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: nil, on: true, counted: %w[commits visits site_visitors], shown: shown) }
    hiding = row.call(%w[commits site_visitors])

    expect([ hiding.shown, row.call(%w[site_visitors visits]).shown, row.call(%w[visits]).with(shown: %w[site_visitors]).shown ])
      .to eq([ %w[commits], %w[site_visitors visits], [] ])
    expect([ hiding.shows?("site_visitors"), hiding.counts?("site_visitors") ]).to eq([ false, true ])
  end

  it "has its builder's switch for a number it counts on a synced repo, and for site visits and site visitors only while they count" do
    repo = build(:github_repo, hidden_numbers: [ "site_visitors" ])
    row = ->(site, counted = %w[commits visits site_visitors]) { described_class.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: repo, on: true, counted: counted, shown: %w[commits], site: site) }
    unsynced = described_class.new(key: "me/gone", name: "gone", rank: 2, color_class: "os-project-3", repo: nil, on: true, counted: %w[commits], shown: %w[commits])

    expect([ row.call(:counting).pick("commits"), row.call(:counting).pick("visits"), row.call(:counting).pick("site_visitors"), unsynced.pick("commits") ])
      .to eq([ true, true, false, nil ])
    expect([ row.call(:paused).pick("visits"), row.call(:off).pick("visits"), row.call(:counting, %w[commits]).pick("visits") ]).to eq([ nil, nil, nil ])
    expect([ row.call(:paused).pick("site_visitors"), row.call(:off).pick("site_visitors"), row.call(:counting, %w[commits]).pick("site_visitors") ])
      .to eq([ nil, nil, nil ])
  end

  it "has no switch for site visitors while its builder hides the site visits they sit beside, and their own pick again once those show" do
    repo = build(:github_repo, hidden_numbers: %w[visits site_visitors])
    row = described_class.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: repo, on: true, counted: %w[commits visits site_visitors],
                              shown: %w[commits], site: :counting)
    expect([ row.pick("visits"), row.pick("site_visitors") ]).to eq([ false, nil ])

    repo.hidden_numbers = [ "site_visitors" ]
    expect([ row.pick("visits"), row.pick("site_visitors") ]).to eq([ true, false ])
  end

  it "puts Paused in the switch's place while Free counts another project, and Set up while its site visits count none, on site visits alone" do
    repo = build(:github_repo)
    row = ->(site, counted = %w[commits visits]) { described_class.new(key: "me/app", name: "app", rank: 0, color_class: "os-project-1", repo: repo, on: true, counted: counted, shown: %w[commits], site: site) }
    unsynced = described_class.new(key: "me/gone", name: "gone", rank: 2, color_class: "os-project-3", repo: nil, on: true, counted: %w[commits], shown: %w[commits])

    expect(%i[counting paused off].map { |site| row.call(site).link("visits") }).to eq([ nil, :paused, :set_up ])
    expect([ row.call(:counting, %w[commits]).link("visits"), row.call(:paused).link("commits"), unsynced.link("visits") ]).to eq([ :set_up, nil, nil ])
    expect(%i[counting paused off].map { |site| row.call(site, %w[commits visits site_visitors]).link("site_visitors") }).to eq([ nil, nil, nil ])
  end
end
