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

  # table: whether the view has its table; cell_changes: whether its cells
  # carry their change.
  def view(repos: [], table: false, cell_changes: false, **options)
    chart = Progress::ChartService.new(user: user, range: "30d", repos: repos).tap(&:call!)
    described_class.new(chart, table: (ProjectsTableSerializer.new(chart, changes: cell_changes) if table), **options).as_json
  end

  it "sends the window, the rows in view, a toggle per number with its group and split, the numbers drawn and the chart" do
    json = view(changes: false, table: false, repos: [ "me/app" ])

    expect(json).to include("range" => "30d", "words" => "last 30 days", "selected" => [ "me/app" ], "drawn" => [ "commits" ], "defaultShow" => [ "commits" ],
                            "table" => nil)
    expect(json["numbers"].sole).to include("key" => "commits", "group" => "On GitHub", "value" => "2", "change" => nil,
                                            "split" => [ { "key" => "me/app", "rank" => 0, "value" => 2 } ])
    expect(json["chart"]["paths"].map { |path| path["key"] }).to eq([ "me/app" ])
  end

  it "writes a dash for a number no row in view shows" do
    user.github_repos.find_by(full_name: "me/app").update!(site_source: "script", site_set_up_at: 3.days.ago, site_first_visit_at: 2.days.ago)
    user.github_repos.find_by(full_name: "me/app").site_visit_days.create!(day: 2.days.ago.to_date, visits: 5, visitors: 2)

    json = view(changes: true, table: false, repos: [ "me/lib" ])

    expect(json["numbers"].map { |number| [ number["key"], number["value"], number["change"] ] }).to eq([ [ "commits", "1", nil ], [ "visits", "–", nil ] ])
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
