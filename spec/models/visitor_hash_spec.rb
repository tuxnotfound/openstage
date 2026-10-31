require "rails_helper"

RSpec.describe VisitorHash do
  it "hashes the address with the day and a key, never as the unkeyed SHA256 rows held before" do
    hash = described_class.of("203.0.113.7")

    expect(hash).to match(/\A\h{64}\z/)
    expect(hash).not_to eq(Digest::SHA256.hexdigest("203.0.113.7#{Date.current}"))
  end

  it "is the same for one address on one day, and another for another address or day" do
    expect(described_class.of("203.0.113.7")).to eq(described_class.of("203.0.113.7", Date.current))
    expect(described_class.of("203.0.113.8")).not_to eq(described_class.of("203.0.113.7"))
    expect(described_class.of("203.0.113.7", Date.yesterday)).not_to eq(described_class.of("203.0.113.7"))
  end

  it "takes its key from the app's secret, so the database alone matches no address" do
    hash = described_class.of("203.0.113.7")
    allow(Rails.application).to receive(:key_generator).and_return(ActiveSupport::KeyGenerator.new("another app's secret"))

    expect(described_class.of("203.0.113.7")).not_to eq(hash)
  end
end
