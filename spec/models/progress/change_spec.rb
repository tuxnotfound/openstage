require "rails_helper"

RSpec.describe Progress::Change do
  it "writes a change against the window before, its arrow carrying the direction" do
    expect(described_class.of(30, 10).to_h).to eq(arrow: "▲", text: "200%", up: true)
    expect(described_class.of(5, 10).to_h).to eq(arrow: "▼", text: "50%", up: false)
    expect(described_class.of(10, 10).to_h).to eq(arrow: "±", text: "0%", up: nil)
  end

  it "writes no change with nothing before to compare with" do
    expect([ described_class.of(3, nil), described_class.of(3, 0) ]).to eq([ nil, nil ])
  end
end
