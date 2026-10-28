require "rails_helper"

RSpec.describe CompareChartSerializer do
  let(:commits) { Progress::Numbers.find("commits") }
  let(:visits) { Progress::Numbers.find("visits") }
  let(:window) { Progress::Window.new(range: "90d", today: Date.new(2026, 10, 28), first_activity: Date.new(2026, 10, 19)) }

  def line(number, values)
    ProgressChart::Compare::Line.new(repo: "me/app", name: "app", rank: 0, number: number, values: values, total: values.sum)
  end

  it "sends each line with its project and its number, the tooltip's columns, and the note around the line styles" do
    chart = ProgressChart::Compare.new(window: window, lines: [ line(commits, [ 3, 1 ]), line(visits, [ 0, 400 ]) ], numbers: [ commits, visits ])

    json = described_class.new(chart).as_json

    expect(json["paths"].map { |path| path.slice("rank", "number", "key") }).to eq([ { "rank" => 0, "number" => "visits", "key" => "me/app" },
                                                                                     { "rank" => 0, "number" => "commits", "key" => "me/app" } ])
    expect(json["heads"]).to eq(%w[commits visits])
    expect(json["columns"].last["rows"]).to eq([ { "key" => "me/app", "name" => "app", "rank" => 0, "values" => %w[1 400] } ])
    expect(json["noteParts"]).to eq("before" => "", "after" => ", each against its own peak in the window; 100% is 3 commits a week and 400 site visits a week.")
    expect(json).to include("indexed" => true, "none" => "Nothing this week", "axis" => [ "Oct 19", "Today" ])
  end

  it "sends no note parts for a chart of one number" do
    chart = ProgressChart::Compare.new(window: window, lines: [ line(commits, [ 3, 1 ]) ], numbers: [ commits ])

    expect(described_class.new(chart).as_json).to include("noteParts" => nil, "indexed" => false, "note" => "Commits per week, one line per project.")
  end
end
