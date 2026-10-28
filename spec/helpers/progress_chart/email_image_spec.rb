require "rails_helper"

RSpec.describe ProgressChart::EmailImage do
  let(:user) { create(:user) }

  # A Thursday: the email's week runs from Monday Oct 12.
  before { travel_to Time.utc(2026, 10, 15, 12) }

  def svg(repos: [])
    section = Progress::ComposeService.new(user: user, range: "week", repos: repos).tap(&:call!).section
    described_class.new(ProgressChart::Trend.new(section, discs: true)).svg
  end

  it "draws a project past the tenth in ink when it is the one project in view, and only its disc beside the other ten" do
    10.times { |i| 2.times { create(:entry, user: user, repo_name: "me/p#{i}", occurred_at: 1.day.ago) } }
    create(:entry, user: user, repo_name: "me/quiet", occurred_at: 1.day.ago)
    create(:entry, user: user, entry_type: "milestone", source: "manual", title: "Shipped quietly", repo_name: "me/quiet", occurred_at: 1.day.ago)

    every = svg
    expect(every.scan("<polyline").size).to eq(10)
    expect(every).not_to include(%(stroke="#{described_class::INK}" stroke-width="6"))
    expect(every).to match(/<circle [^>]*fill="#{described_class::INK}"/)
    expect(svg(repos: [ "me/quiet" ])).to include(%(stroke="#{described_class::INK}" stroke-width="6"))
  end
end
