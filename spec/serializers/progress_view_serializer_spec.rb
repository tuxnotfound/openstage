require "rails_helper"

RSpec.describe ProgressViewSerializer do
  let(:user) { create(:user) }

  def view(**options)
    chart = Progress::ChartService.new(user: user, range: "30d", **options.except(:linked_id)).tap(&:call!)
    described_class.new(chart, **options.slice(:linked_id)).as_json
  end

  it "leaves out the anchor of the entry a link pointed at, which shows above the page" do
    linked = create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 1.day.ago)
    other = create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 2.days.ago)

    items = view(linked_id: linked.id)["shipped"]["items"]

    expect(items.to_h { |item| [ item["id"], item["anchor"] ] }).to eq(linked.id => nil, other.id => "entry-#{other.id}")
  end

  # Entries refuse such a link when saved; an older row may still hold one.
  it "links an entry only to an http address" do
    create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 1.day.ago).update_column(:url, "javascript:alert(1)")

    expect(view["shipped"]["items"].first["url"]).to be_nil
  end

  describe "the chart filter" do
    before do
      travel_to Time.utc(2026, 10, 28, 12)
      create(:github_repo, user: user, full_name: "me/app", name: "app")
      2.times { create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago) }
      create(:entry, user: user, repo_name: "me/lib", occurred_at: 3.days.ago)
      create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
    end

    it "sends a toggle per number with its total and each project's part, the numbers drawn, and the table" do
      json = view

      expect(json["numbers"]).to eq([ { "key" => "commits", "label" => "Commits", "word" => "commits", "group" => "On GitHub", "value" => "3", "change" => nil,
                                        "split" => [ { "repo" => "me/app", "rank" => 0, "value" => 2 }, { "repo" => "me/lib", "rank" => 1, "value" => 1 } ] } ])
      expect(json).to include("range" => "30d", "words" => "last 30 days", "selected" => [], "drawn" => [ "commits" ], "defaultShow" => [ "commits" ])
      expect(json["table"]["rows"].map { |row| [ row["name"], row["on"], row["cells"].map { |cell| cell["value"] } ] })
        .to eq([ [ "app", true, [ "2" ] ], [ "lib", true, [ "1" ] ] ])
    end

    it "gives the dashboard each number's change, its own table, and no What shipped" do
      json = view(builder: true)

      expect(json["numbers"].first["change"]).to eq("arrow" => "▲", "text" => "200%", "up" => true)
      expect(json["table"]["rows"].flat_map { |row| row["cells"].pluck("change") }.uniq).to eq([ nil ])
      expect(json["table"]["rows"].first).to include("edit" => "/projects/#{user.github_repos.first.id}/edit", "switch" => "/projects/#{user.github_repos.first.id}/numbers")
      expect(json["shipped"]).to be_nil
    end

    it "leaves the table off a project's page" do
      expect(view(repos: [ "me/app" ], lone: true)["table"]).to be_nil
    end
  end
end
