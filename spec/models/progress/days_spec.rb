require "rails_helper"

RSpec.describe Progress::Days do
  it "reads two real days, either order, and writes them back in order" do
    expect(described_class.parse("2026-10-03..2026-10-28").to_s).to eq("2026-10-03..2026-10-28")
    expect(described_class.parse("2026-10-28..2026-10-03").to_s).to eq("2026-10-03..2026-10-28")
    expect(described_class.of("2026-10-28", "2026-10-03").count).to eq(26)
  end

  it "starts no earlier than 2008" do
    expect(described_class.parse("1999-05-01..2009-01-01").to_s).to eq("2008-01-01..2009-01-01")
    expect(described_class.parse("1999-05-01..2001-01-01")).to be_nil
  end

  it "is nothing for anything but two real days" do
    [ nil, "", "30d", "2026-10-03", "2026-10-03..", "2026-02-30..2026-03-01", "2026-10-03..2026-10-28..2026-11-01",
      "26-10-03..26-10-28", "2026-10-3..2026-10-28", "2026-10-03...2026-10-28", "2026-13-01..2026-10-28" ].each do |text|
      expect(described_class.parse(text)).to be_nil, text.inspect
    end
    expect(described_class.of("2026-10-03", "")).to be_nil
  end

  it "ends today at the latest, and is nothing when it starts after today" do
    today = Date.new(2026, 10, 15)

    expect(described_class.parse("2026-10-01..2026-12-31").upto(today).to_s).to eq("2026-10-01..2026-10-15")
    expect(described_class.parse("2026-10-16..2026-12-31").upto(today)).to be_nil
  end
end
