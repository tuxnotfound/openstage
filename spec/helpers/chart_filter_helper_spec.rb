require "rails_helper"

RSpec.describe ChartFilterHelper, type: :helper do
  it "writes a change against the window before, its arrow carrying the direction" do
    expect(helper.chart_change(30, 10)).to eq(arrow: "▲", text: "200%", up: true)
    expect(helper.chart_change(5, 10)).to eq(arrow: "▼", text: "50%", up: false)
    expect(helper.chart_change(10, 10)).to eq(arrow: "±", text: "0%", up: nil)
  end

  it "writes no change with nothing before to compare with" do
    expect([ helper.chart_change(3, nil), helper.chart_change(3, 0) ]).to eq([ nil, nil ])
  end

  it "colours an arrow up or down, and leaves no change uncoloured" do
    expect([ helper.chart_tone(true), helper.chart_tone(false), helper.chart_tone(nil) ]).to eq([ "text-up", "text-down", nil ])
  end
end
