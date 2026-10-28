require "rails_helper"

RSpec.describe ProgressHelper, type: :helper do
  describe "#progress_ago" do
    it "says how long ago a day was, in the unit that reads best" do
      today = Date.new(2026, 10, 15)

      expect([ 0, 1, 5, 20, 90 ].map { |days| helper.progress_ago(today - days, today) })
        .to eq([ "today", "yesterday", "5 days ago", "3 weeks ago", "3 months ago" ])
    end
  end

  describe "#project_class" do
    it "colours the first ten projects by rank and no project in ink, and gives the rest no class" do
      expect([ 0, 9, 10, nil ].map { |rank| helper.project_class(rank) }).to eq([ "os-project-1", "os-project-10", nil, "os-project-none" ])
    end
  end
end
