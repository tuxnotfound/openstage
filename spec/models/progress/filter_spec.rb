require "rails_helper"

RSpec.describe Progress::Filter do
  def filter(**params)
    described_class.from(ActionController::Parameters.new(params))
  end

  it "reads the window, the numbers in line order and the projects, comma-separated" do
    view = filter(range: "30d", show: "visits,commits", projects: "me/app,me/lib")

    expect([ view.range, view.show, view.projects ]).to eq([ "30d", %w[visits commits], %w[me/app me/lib] ])
  end

  it "leaves out what it does not know: a window, a number, a blank" do
    view = filter(range: "7d", show: "visits, mrr,visits", projects: " ,")

    expect([ view.range, view.show, view.projects ]).to eq([ nil, %w[visits], [] ])
  end

  it "reads days picked as the range, in order, and nothing that is not two real days" do
    expect(filter(range: "2026-10-28..2026-10-03").range).to eq("2026-10-03..2026-10-28")
    expect(filter(range: "2007-06-01..2008-02-01").range).to eq("2008-01-01..2008-02-01")
    expect([ filter(range: "2026-02-30..2026-03-01"), filter(range: "2026-10-03"), filter(range: %w[30d]) ].map(&:range)).to eq([ nil, nil, nil ])
  end

  it "reads the window's form, from and to, as the same days, over any range" do
    expect(filter(from: "2026-10-03", to: "2026-10-28", range: "90d").range).to eq("2026-10-03..2026-10-28")
    expect(filter(from: "2026-10-28", to: "2026-10-03").range).to eq("2026-10-03..2026-10-28")
    expect(filter(from: "2026-10-03", to: "", range: "90d").range).to eq("90d")
    expect(filter(from: "soon", to: "2026-10-03").range).to be_nil
    expect(described_class.from_analytics(ActionController::Parameters.new(from: "2026-10-03", to: "2026-10-04")).range).to eq("2026-10-03..2026-10-04")
  end

  it "still reads the old links: repo[] and repo= for the projects, and a single show value" do
    expect(filter(repo: %w[me/app me/lib]).projects).to eq(%w[me/app me/lib])
    expect(filter(repo: "me/app").projects).to eq(%w[me/app])
    expect(filter(projects: "me/lib", repo: "me/app").projects).to eq(%w[me/lib])
    expect(filter(show: "visits").show).to eq(%w[visits])
  end

  it "leaves the old repo params to a page that reads them as something else" do
    expect(described_class.from(ActionController::Parameters.new(repo: "me/app"), repo: false).projects).to eq([])
  end

  it "reads analytics' old links: pages[] for its pages, and metric for the one number it drew" do
    old = described_class.from_analytics(ActionController::Parameters.new(metric: "site", pages: %w[page me/app], range: "7d"))
    expect([ old.range, old.show, old.projects ]).to eq([ nil, %w[visits], %w[page me/app] ])

    now = described_class.from_analytics(ActionController::Parameters.new(show: "views,commits", projects: "page", metric: "site", pages: %w[me/app]))
    expect([ now.show, now.projects ]).to eq([ %w[views commits], %w[page] ])
  end

  it "takes fifty projects at most" do
    expect(filter(projects: (1..60).map { |i| "me/#{i}" }.join(",")).projects.size).to eq(50)
  end

  it "keeps in view the coloured projects a list names, and all of them for none, every one, or only ones past the palette" do
    colored = %w[me/a me/b me/c]

    expect(described_class.in_view(%w[me/c me/a], colored)).to eq(%w[me/a me/c])
    expect([ [], colored, %w[me/k me/l], nil ].map { |named| described_class.in_view(named, colored) }).to eq([ [], [], [], [] ])
    expect(described_class.in_view(%w[me/b me/k], colored)).to eq(%w[me/b])
  end
end
