require "rails_helper"

RSpec.describe Progress::Numbers do
  it "lists every number in the pages' order, commits first, then site visits and site visitors" do
    expect(described_class::ALL.map(&:key)).to eq(%w[commits visits site_visitors visitors views follows clicks])
    expect(described_class::ALL.map(&:group).uniq).to eq([ "On GitHub", "On your websites", "On Openstage" ])
  end

  it "lets a project's builder pick only the numbers a project counts, the ones its website counts among them" do
    expect(described_class::PICKABLE).to eq(%w[commits visits site_visitors])
    expect(described_class::SITE).to eq(%w[visits site_visitors])
    expect(described_class::SITE.map { |key| described_class.find(key).group }.uniq).to eq([ "On your websites" ])
  end

  it "draws every number in lines of its own but site visitors, which sit beside site visits in their tooltip" do
    expect(described_class::ALL.reject(&:drawable?).map { |number| [ number.key, number.beside ] }).to eq([ %w[site_visitors visits] ])
    expect(described_class.beside(described_class.find("visits")).map(&:key)).to eq(%w[site_visitors])
    expect(described_class.beside(described_class.find("views"))).to be_empty
  end

  it "names site visitors apart from Openstage's own visitors" do
    site_visitors = described_class.find("site_visitors")

    expect([ site_visitors.label, site_visitors.word, site_visitors.word_after("1"), site_visitors.word_after("3") ])
      .to eq([ "Site visitors", "site visitors", "site visitor", "site visitors" ])
    expect(described_class.find("visitors").label).to eq("Visitors")
  end

  it "finds a number by its key, and puts keys in the pages' order once each" do
    expect(described_class.find("visits").label).to eq("Site visits")
    expect(described_class.find("mrr")).to be_nil
    expect(described_class.in_order(%w[visits commits visits nope]).map(&:key)).to eq(%w[commits visits])
  end

  it "names a number inside a sentence in lower case, unless its name is in capitals" do
    expect(described_class.find("visits").word).to eq("site visits")
    expect(described_class::Number.new(key: "mrr", label: "MRR", one: "MRR", group: "On Stripe", level: true, money: true, pickable: true).word).to eq("MRR")
  end

  it "names one of a number in the singular, and any other amount in the plural" do
    clicks = described_class.find("clicks")
    expect([ clicks.word_after("1"), clicks.word_after("1.0"), clicks.word_after("12") ]).to eq([ "click out", "clicks out", "clicks out" ])
  end
end
