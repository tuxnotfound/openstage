require "rails_helper"

RSpec.describe ProgressChart::Palette do
  # The stylesheet's colour tokens by mode: light's in @theme, dark's where
  # the body turns dark, a token it leaves out there keeping light's.
  def tokens
    css = Rails.root.join("app/assets/tailwind/application.css").read
    light = css[/@theme static \{(.*?)\n\}/m, 1].scan(/--color-([\w-]+): (#\h{6});/).to_h
    { light: light, dark: light.merge(css[/@variant dark \{(.*?)\}/m, 1].scan(/--color-([\w-]+): (#\h{6});/).to_h) }
  end

  def contrast(one, other)
    high, low = [ described_class.luminance(one), described_class.luminance(other) ].minmax.reverse
    (high + 0.05) / (low + 0.05)
  end

  it "colors the ten busiest projects and grays the rest" do
    expect((0..10).map { |rank| described_class.project_color(rank) })
      .to eq(%w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #6250d6 #e34948 #9e8eff #7c3856 #8A8F98])
  end

  it "uses the dark palette and the card's faint gray on a card" do
    expect([ described_class.project_color(9, :dark), described_class.project_color(10, :light), described_class.project_color(nil, :dark) ])
      .to eq(%w[#8b4664 #8A8E86 #6B7378])
  end

  it "gives the marks of the ten busiest projects their colour's class, the rest grey and no project ink" do
    expect([ 0, 9, 10, nil ].map { |rank| described_class.project_class(rank) }).to eq(%w[os-project-1 os-project-10 os-project-other os-project-none])
  end

  it "sets the page's tokens to the same ten colours in each mode" do
    expect(tokens.transform_values { |set| (1..10).map { |n| set["project-#{n}"] } }).to eq(described_class::PROJECT_COLORS)
  end

  it "puts text on each new colour in whichever of the mode's ground and ink contrasts more with it" do
    tokens.each do |mode, set|
      (7..10).each do |n|
        best = [ set["ground"], set["ink"] ].max_by { |text| contrast(text, set["project-#{n}"]) }
        expect(set["on-project-#{n}"]).to eq(best), "#{mode} #{n}"
      end
    end
  end

  it "puts dark text on a light colour and white on a deep one, as the page's tokens do" do
    expect(%w[#2f6ee0 #eb6834 #008300 #6250d6 #e34948 #9e8eff #7c3856 #0E0F12].map { |hex| described_class.ink_on(hex) })
      .to eq(%w[#FFFFFF #111111 #FFFFFF #FFFFFF #111111 #111111 #FFFFFF #FFFFFF])
  end
end
