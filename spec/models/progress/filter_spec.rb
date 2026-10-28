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

  it "still reads the old links: repo[] and repo= for the projects, and a single show value" do
    expect(filter(repo: %w[me/app me/lib]).projects).to eq(%w[me/app me/lib])
    expect(filter(repo: "me/app").projects).to eq(%w[me/app])
    expect(filter(projects: "me/lib", repo: "me/app").projects).to eq(%w[me/lib])
    expect(filter(show: "visits").show).to eq(%w[visits])
  end

  it "leaves the old repo params to a page that reads them as something else" do
    expect(described_class.from(ActionController::Parameters.new(repo: "me/app"), repo: false).projects).to eq([])
  end

  it "takes fifty projects at most" do
    expect(filter(projects: (1..60).map { |i| "me/#{i}" }.join(",")).projects.size).to eq(50)
  end
end
