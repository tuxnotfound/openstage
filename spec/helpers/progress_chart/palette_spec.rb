require "rails_helper"

RSpec.describe ProgressChart::Palette do
  it "colors the six busiest projects and grays the rest" do
    expect((0..6).map { |rank| described_class.project_color(rank) })
      .to eq(%w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #8A8F98])
  end

  it "uses the dark palette and the card's faint gray on a card" do
    expect([ described_class.project_color(0, :dark), described_class.project_color(6, :light), described_class.project_color(nil, :dark) ])
      .to eq(%w[#3987e5 #8A8E86 #6B7378])
  end

  it "puts dark text on a light colour and white on a deep one, as the page's tokens do" do
    expect(%w[#2f6ee0 #eb6834 #008300 #8A8F98 #0E0F12].map { |hex| described_class.ink_on(hex) })
      .to eq(%w[#FFFFFF #111111 #FFFFFF #111111 #FFFFFF])
  end
end
