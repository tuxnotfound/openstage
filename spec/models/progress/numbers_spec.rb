require "rails_helper"

RSpec.describe Progress::Numbers do
  it "lists every number in the pages' order, commits first, then site visits" do
    expect(described_class::ALL.map(&:key)).to eq(%w[commits visits visitors views follows clicks])
    expect(described_class::ALL.map(&:group).uniq).to eq([ "On GitHub", "On your websites", "On Openstage" ])
  end

  it "lets a project's builder pick only the numbers a project counts" do
    expect(described_class::PICKED).to eq(%w[commits visits])
  end

  it "finds a number by its key, and puts keys in the pages' order once each" do
    expect(described_class.find("visits").label).to eq("Site visits")
    expect(described_class.find("mrr")).to be_nil
    expect(described_class.in_order(%w[visits commits visits nope]).map(&:key)).to eq(%w[commits visits])
  end

  it "names a number inside a sentence in lower case, unless its name is in capitals" do
    expect(described_class.find("visits").word).to eq("site visits")
    expect(described_class::Number.new(key: "mrr", label: "MRR", group: "On Stripe", level: true, money: true, picked: true).word).to eq("MRR")
  end
end
