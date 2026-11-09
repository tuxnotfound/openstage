require "rails_helper"

RSpec.describe Revenue::Levels do
  let(:day) { Date.new(2026, 11, 6) }

  def row(repo_id, on, currency, mrr)
    described_class::Row.new(repo_id: repo_id, day: on, currency: currency, mrr: mrr)
  end

  before do
    ExchangeRate.create!(currency: "usd", day: day - 1, per_euro: 1)
    ExchangeRate.create!(currency: "usd", day: day, per_euro: 2)
  end

  it "keeps one currency as it is, in its units, and reads no rates" do
    allow(ExchangeRate).to receive(:where).and_call_original

    levels = described_class.new([ row(1, day, "sek", 120_000) ], customers: { 1 => { day => 3 } })

    expect(levels.currency).to eq("sek")
    expect(levels.mrr(1)).to eq(day => 1200.0)
    expect(levels.customers(1)).to eq(day => 3)
    expect(ExchangeRate).not_to have_received(:where)
  end

  it "adds a project's products up on each day" do
    levels = described_class.new([ row(1, day, "usd", 1000), row(1, day, "usd", 500) ])

    expect(levels.mrr(1)).to eq(day => 15.0)
  end

  it "takes the currency most of the revenue is in on the latest day, worth in euros, and converts the rest at each day's rate" do
    levels = described_class.new([ row(1, day, "usd", 10_000), row(1, day, "eur", 6000), row(1, day - 1, "eur", 1000) ])

    # $100 is €50 that day, under the €60.
    expect(levels.currency).to eq("eur")
    expect(levels.mrr(1)).to eq(day => 110.0, day - 1 => 10.0)
  end

  it "converts into the larger currency too, at that day's rate" do
    levels = described_class.new([ row(1, day, "usd", 30_000), row(1, day, "eur", 10_000), row(1, day - 1, "eur", 1000) ])

    expect(levels.currency).to eq("usd")
    expect(levels.mrr(1)).to eq(day => 500.0, day - 1 => 10.0)
  end

  it "leaves out a currency the ECB has no rate for, names it, and still counts its customers" do
    levels = described_class.new([ row(1, day, "usd", 10_000), row(1, day, "ngn", 500_000_000) ], customers: { 1 => { day => 7 } })

    expect(levels.currency).to eq("usd")
    expect(levels.mrr(1)).to eq(day => 100.0)
    expect(levels.customers(1)).to eq(day => 7)
    expect(levels.left_out).to eq(%w[ngn])
  end

  it "takes the largest amount when the ECB can say nothing of any" do
    levels = described_class.new([ row(1, day, "ngn", 90_000), row(1, day, "xof", 100) ])

    expect(levels.currency).to eq("ngn")
    expect(levels.left_out).to eq(%w[xof])
  end

  it "has no currency without a row, and nothing for a project it does not hold" do
    levels = described_class.new([])

    expect(levels.currency).to be_nil
    expect(levels.mrr(1)).to eq({})
    expect(levels.customers(1)).to eq({})
  end
end
