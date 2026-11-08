require "rails_helper"

RSpec.describe Revenue::Rates do
  let(:friday) { Date.new(2026, 11, 6) }
  let(:rates) { described_class.new("usd" => [ [ friday - 1, 1.0 ], [ friday, 1.25 ] ], "gbp" => [ [ friday, 0.5 ] ]) }

  it "converts an amount at its day's rate, through the euro" do
    expect(rates.convert(125, "usd", "eur", friday)).to eq(100.0)
    expect(rates.convert(100, "eur", "usd", friday)).to eq(125.0)
    expect(rates.convert(125, "usd", "gbp", friday)).to eq(50.0)
    expect(rates.convert(100, "usd", "eur", friday - 1)).to eq(100.0)
  end

  it "takes the last rate before a day the ECB does not publish, and the newest for today" do
    expect(rates.convert(125, "usd", "eur", friday + 1)).to eq(100.0)
    expect(rates.convert(125, "usd", "eur", friday + 40)).to eq(100.0)
  end

  it "leaves a currency alone in itself, whatever the ECB has" do
    expect(rates.convert(70, "ngn", "ngn", friday)).to eq(70)
  end

  it "converts nothing where the ECB has no rate" do
    expect(rates.convert(100, "ngn", "usd", friday)).to be_nil
    expect(rates.convert(100, "usd", "ngn", friday)).to be_nil
    expect(rates.convert(100, "usd", "eur", friday - 2)).to be_nil
  end

  it "reads the rates of the currencies asked for, far enough back for the first day's" do
    ExchangeRate.create!(currency: "usd", day: friday - 3, per_euro: 2)
    ExchangeRate.create!(currency: "usd", day: friday - 30, per_euro: 9)
    ExchangeRate.create!(currency: "gbp", day: friday, per_euro: 9)

    read = described_class.for(%w[usd eur], from: friday)

    expect(read.convert(100, "usd", "eur", friday)).to eq(50.0)
    expect(read.convert(100, "gbp", "eur", friday)).to be_nil
  end
end
