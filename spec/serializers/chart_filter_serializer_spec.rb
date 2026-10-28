require "rails_helper"

RSpec.describe ChartFilterSerializer do
  let(:user) { create(:user) }

  before do
    travel_to Time.utc(2026, 10, 28, 12)
    create(:github_repo, user: user, full_name: "me/app", name: "app")
    2.times { create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago) }
    create(:entry, user: user, repo_name: "me/lib", occurred_at: 3.days.ago)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
  end

  def view(repos: [], **options)
    chart = Progress::ChartService.new(user: user, range: "30d", repos: repos).tap(&:call!)
    described_class.new(chart, **options).as_json
  end

  it "sends the window, the rows in view, a toggle per number with its group and split, the numbers drawn and the chart" do
    json = view(changes: false, table: false, repos: [ "me/app" ])

    expect(json).to include("range" => "30d", "words" => "last 30 days", "selected" => [ "me/app" ], "drawn" => [ "commits" ], "defaultShow" => [ "commits" ],
                            "table" => nil)
    expect(json["numbers"].sole).to include("key" => "commits", "group" => "On GitHub", "value" => "2", "change" => nil,
                                            "split" => [ { "repo" => "me/app", "rank" => 0, "value" => 2 } ])
    expect(json["chart"]["paths"].map { |path| path["repo"] }).to eq([ "me/app" ])
  end

  it "gives the toggles their change, and the table's cells theirs only when asked" do
    toggles = view(changes: true, table: true)
    expect(toggles["numbers"].sole["change"]).to eq("arrow" => "▲", "text" => "200%", "up" => true)
    expect(toggles["table"]["rows"].map { |row| row["cells"].sole["change"] }).to eq([ nil, nil ])

    cells = view(changes: true, table: true, cell_changes: true)
    expect(cells["table"]["rows"].map { |row| [ row["name"], row["cells"].sole["change"] ] })
      .to eq([ [ "app", { "arrow" => "▲", "text" => "100%", "up" => true } ], [ "lib", nil ] ])
  end
end
