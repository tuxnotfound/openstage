require "rails_helper"

RSpec.describe Revenue::ReadRatesService do
  let(:rate) { { currency: "usd", day: Date.new(2026, 11, 6), per_euro: "1.0842".to_d } }

  it "reads the whole history on the first read" do
    allow(EcbGateway).to receive(:all_rates).and_return([ rate ])
    allow(EcbGateway).to receive(:recent_rates)

    described_class.new.call!

    expect(ExchangeRate.pluck(:currency, :day, :per_euro)).to eq([ [ "usd", Date.new(2026, 11, 6), "1.0842".to_d ] ])
    expect(EcbGateway).not_to have_received(:recent_rates)
  end

  it "keeps nothing of a first read cut short, so the next read fetches the whole history" do
    cut_short = Enumerator.new do |rates|
      1001.times { |days| rates << rate.merge(day: rate[:day] - days) }
      raise ApplicationGateway::Error, "The ECB sent broken XML"
    end
    allow(EcbGateway).to receive(:all_rates).and_return(cut_short)

    expect { described_class.new.call! }.to raise_error(ApplicationGateway::Error)
    expect(ExchangeRate.exists?).to be(false)
  end

  it "reads the last 90 days after that, and takes a rate the ECB corrected" do
    ExchangeRate.create!(currency: "usd", day: Date.new(2026, 11, 6), per_euro: 1)
    allow(EcbGateway).to receive(:recent_rates).and_return([ rate, rate.merge(day: Date.new(2026, 11, 5)) ])
    allow(EcbGateway).to receive(:all_rates)

    described_class.new.call!

    expect(ExchangeRate.order(:day).pluck(:per_euro)).to eq([ "1.0842".to_d, "1.0842".to_d ])
    expect(EcbGateway).not_to have_received(:all_rates)
  end
end
