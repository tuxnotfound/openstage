require "rails_helper"

RSpec.describe Revenue::Money do
  it "writes whole units, with the currency's symbol or its code" do
    expect(described_class.format(421_049, "usd")).to eq("$4,210")
    expect(described_class.format(42_050, "eur")).to eq("€421")
    expect(described_class.format(52_000, "jpy")).to eq("¥52,000")
    expect(described_class.format(120_000, "sek")).to eq("1,200 SEK")
    expect(described_class.format(52_000, "kwd")).to eq("52 KWD")
  end

  it "reads ISK and UGX as Stripe writes them, 5 as 500, though neither has a smaller unit" do
    expect(described_class.units(500, "ugx")).to eq(5.0)
    expect(described_class.units(500, "isk")).to eq(5.0)
    expect(described_class.units(500, "krw")).to eq(500.0)
  end

  it "says what an amount is in the currency's units, and writes units whole" do
    expect(described_class.units(1250, "usd")).to eq(12.5)
    expect(described_class.units(1250, "jpy")).to eq(1250.0)
    expect(described_class.write(4210.49, "usd")).to eq("$4,210")
  end
end
