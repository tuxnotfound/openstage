require "rails_helper"

RSpec.describe Revenue::Money do
  it "writes whole units, with the currency's symbol or its code" do
    expect(described_class.format(421_049, "usd")).to eq("$4,210")
    expect(described_class.format(42_050, "eur")).to eq("€421")
    expect(described_class.format(52_000, "jpy")).to eq("¥52,000")
    expect(described_class.format(120_000, "sek")).to eq("1,200 SEK")
  end
end
