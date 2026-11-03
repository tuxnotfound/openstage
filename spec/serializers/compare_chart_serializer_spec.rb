require "rails_helper"

RSpec.describe CompareChartSerializer do
  let(:commits) { Progress::Numbers.find("commits") }
  let(:visits) { Progress::Numbers.find("visits") }
  let(:window) { Progress::Window.new(range: "90d", today: Date.new(2026, 10, 28), first_activity: Date.new(2026, 10, 19)) }

  def line(number, values)
    ProgressChart::Compare::Line.new(repo: "me/app", name: "app", rank: 0, color_class: "os-project-1", number: number, values: values, total: values.sum)
  end

  it "sends each line with its project, its colour and its number, and the tooltip's columns, with no note and no value on the gridlines" do
    chart = ProgressChart::Compare.new(window: window, lines: [ line(commits, [ 3, 1 ]), line(visits, [ 0, 400 ]) ], numbers: [ commits, visits ])

    json = described_class.new(chart).as_json

    expect(json["paths"].map { |path| path.slice("colorClass", "number", "key") }).to eq([ { "colorClass" => "os-project-1", "number" => "visits", "key" => "me/app" },
                                                                                           { "colorClass" => "os-project-1", "number" => "commits", "key" => "me/app" } ])
    expect(json["tips"]).to eq([ { "key" => "commits", "label" => "Commits", "line" => true }, { "key" => "visits", "label" => "Site visits", "line" => true } ])
    expect(json["columns"].last["rows"]).to eq([ { "key" => "me/app", "name" => "app", "colorClass" => "os-project-1", "values" => %w[1 400] } ])
    expect(json["ticks"].pluck("value")).to eq([ nil, nil ])
    expect(json).to include("indexed" => true, "note" => nil, "none" => "Nothing this week", "axis" => [ "Oct 19", "Today" ])
  end

  it "heads the tooltip's columns with each number with lines and, with no line, the number beside it, each row's values in their order" do
    chart = ProgressChart::Compare.new(window: window, lines: [ line(visits, [ 0, 400 ]) ], beside: [ line(Progress::Numbers.find("site_visitors"), [ 0, 120 ]) ],
                                       numbers: [ visits ])

    json = described_class.new(chart).as_json

    expect(json["tips"]).to eq([ { "key" => "visits", "label" => "Site visits", "line" => true }, { "key" => "site_visitors", "label" => "Site visitors", "line" => false } ])
    expect(json["columns"].last["rows"].sole["values"]).to eq(%w[400 120])
    expect(json["paths"].pluck("number")).to eq(%w[visits])
    expect(json).to include("indexed" => false, "note" => nil)
  end

  it "sends a chart of one number with its values on the gridlines and no note" do
    chart = ProgressChart::Compare.new(window: window, lines: [ line(commits, [ 3, 1 ]) ], numbers: [ commits ])

    json = described_class.new(chart).as_json
    expect(json["ticks"].pluck("value")).to eq(%w[2 4])
    expect(json).to include("indexed" => false, "note" => nil)
  end
end
