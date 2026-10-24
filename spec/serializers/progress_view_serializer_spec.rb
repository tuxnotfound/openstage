require "rails_helper"

RSpec.describe ProgressViewSerializer do
  let(:user) { create(:user) }

  def section
    Progress::ComposeService.new(user: user, range: "30d", rolling: true).tap(&:call!).section
  end

  it "leaves out the anchor of the entry a link pointed at, which shows above the page" do
    linked = create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 1.day.ago)
    other = create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 2.days.ago)

    items = described_class.new(section, linked_id: linked.id).as_json["shipped"]["items"]

    expect(items.to_h { |item| [ item["id"], item["anchor"] ] }).to eq(linked.id => nil, other.id => "entry-#{other.id}")
  end

  # Entries refuse such a link when saved; an older row may still hold one.
  it "links an entry only to an http address" do
    create(:entry, user: user, entry_type: "milestone", source: "manual", occurred_at: 1.day.ago).update_column(:url, "javascript:alert(1)")

    expect(described_class.new(section).as_json["shipped"]["items"].first["url"]).to be_nil
  end
end
