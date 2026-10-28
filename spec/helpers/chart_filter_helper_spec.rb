require "rails_helper"

RSpec.describe ChartFilterHelper, type: :helper do
  it "colours an arrow up or down, and leaves no change uncoloured" do
    expect([ helper.chart_tone(true), helper.chart_tone(false), helper.chart_tone(nil) ]).to eq([ "text-up", "text-down", nil ])
  end
end
