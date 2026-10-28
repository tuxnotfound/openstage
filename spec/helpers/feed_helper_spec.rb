require "rails_helper"

RSpec.describe FeedHelper, type: :helper do
  describe "#feed_color" do
    it "gives a builder one of the ten project colours by their id, the same on every visit" do
      expect([ 1, 7, 10, 23 ].map { |id| helper.feed_color(build(:user, id: id)) }).to eq(%w[os-project-2 os-project-8 os-project-1 os-project-4])
    end
  end
end
