require "rails_helper"

RSpec.describe ProgressChart::Palette do
  it "colors the six busiest projects and grays the rest" do
    expect((0..6).map { |rank| described_class.project_color(rank) })
      .to eq(%w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #9CA3AF])
  end

  it "uses the dark palette and the card's faint gray on a card" do
    expect([ described_class.project_color(0, :dark), described_class.project_color(6, :light), described_class.project_color(nil, :dark) ])
      .to eq(%w[#3987e5 #8A8E86 #6B7378])
  end
end
