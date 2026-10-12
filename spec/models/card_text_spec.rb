require "rails_helper"

RSpec.describe CardText do
  it "measures DM Sans by weight, wider when bolder" do
    regular = described_class.width("Openstage", size: 20)
    bold = described_class.width("Openstage", size: 20, weight: 700)

    expect(regular).to be_within(0.01).of(20 * (774 + 626 + 568 + 574 + 502 + 392 + 544 + 558 + 568) / 1000.0)
    expect(bold).to be > regular
  end

  it "measures DM Mono at six tenths of an em, plus letter-spacing" do
    expect(described_class.width("W41", size: 10, mono: true, spacing: 1)).to eq(21.0)
  end

  it "gives an accented letter its base letter's width" do
    expect(described_class.width("é", size: 10)).to eq(described_class.width("e", size: 10))
  end
end
