require "rails_helper"

RSpec.describe Progress::Counts do
  let(:counts) do
    described_class.new(days: { "commits" => { "me/app" => { Date.new(2026, 10, 1) => 2, Date.new(2026, 10, 7) => 5 } } },
                        firsts: { "commits" => { "me/app" => Date.new(2026, 3, 1), "me/lib" => Date.new(2026, 5, 1) } })
  end

  def bucket(first, last)
    Progress::Period::Bucket.new(index: 0, first: first, last: last, monday: first, current: false)
  end

  it "adds up a project's count over some days, or over every day counted" do
    expect(counts.sum("commits", "me/app", Date.new(2026, 10, 2)..Date.new(2026, 10, 7))).to eq(5)
    expect(counts.sum("commits", "me/app")).to eq(7)
    expect(counts.sum("visits", "me/app")).to eq(0)
  end

  it "finds the first day any of some projects counted a number" do
    expect(counts.first_day("commits", %w[me/lib me/app])).to eq(Date.new(2026, 3, 1))
    expect(counts.first_day("commits", %w[me/lib])).to eq(Date.new(2026, 5, 1))
    expect(counts.first_day("visits", %w[me/app])).to be_nil
  end

  it "sums a project's days at each point, or averages each day's last seven" do
    week = bucket(Date.new(2026, 10, 1), Date.new(2026, 10, 7))
    day = bucket(Date.new(2026, 10, 7), Date.new(2026, 10, 7))

    expect(counts.per_point("commits", "me/app", [ week, day ])).to eq([ 7, 5 ])
    expect(counts.per_point("commits", "me/app", [ day ], average: true)).to eq([ 1.0 ])
  end
  it "reads a flow above zero over days that hold any of it" do
    expect(counts.above_zero?("commits", "me/app", Date.new(2026, 10, 2)..Date.new(2026, 10, 7))).to be(true)
    expect(counts.above_zero?("commits", "me/app", Date.new(2026, 10, 2)..Date.new(2026, 10, 6))).to be(false)
    expect([ counts.above_zero?("commits", "me/app"), counts.above_zero?("visits", "me/app") ]).to eq([ true, false ])
  end

  describe "a level" do
    let(:may) { Date.new(2026, 5, 1) }
    let(:june) { Date.new(2026, 6, 1) }
    let(:counts) do
      described_class.new(days: { "mrr" => { "me/app" => { may => 10.0, june => 30.0 } } }, firsts: { "mrr" => { "me/app" => may } },
                          through: june, currency: "usd")
    end

    it "stands at its last day's value over some days, never their sum, and stood at nothing on a day with no revenue" do
      expect(counts.sum("mrr", "me/app", may..may)).to eq(10.0)
      expect(counts.sum("mrr", "me/app", may..june)).to eq(30.0)
      expect(counts.sum("mrr", "me/app", (may + 1)..(may + 2))).to eq(0)
    end

    it "carries the last read to the days after it, and stands there with no days named" do
      expect(counts.sum("mrr", "me/app", june..(june + 9))).to eq(30.0)
      expect(counts.sum("mrr", "me/app")).to eq(30.0)
    end

    it "gives each point what it stood at on the point's last day, however it is averaged" do
      bucket = Struct.new(:first, :last)
      points = [ bucket.new(may - 10, may - 5), bucket.new(may, may + 20), bucket.new(june, june + 5) ]

      expect(counts.per_point("mrr", "me/app", points, average: true)).to eq([ 0, 0, 30.0 ])
      expect(counts.per_point("mrr", "me/app", [ bucket.new(may, may) ])).to eq([ 10.0 ])
    end

    it "reads above zero over days it stood above zero on any of, and with no days named while it stands there today" do
      expect(counts.above_zero?("mrr", "me/app", (may - 9)..may)).to be(true)
      expect(counts.above_zero?("mrr", "me/app", (may - 9)..(may - 1))).to be(false)
      expect(counts.above_zero?("mrr", "me/app", (june + 5)..(june + 9))).to be(true)
      expect(counts.above_zero?("mrr", "me/app")).to be(true)
    end

    it "reads at nothing today once it fell to nothing, and while it rounds to nothing as the pages write it" do
      gone = described_class.new(days: { "mrr" => { "me/app" => { may => 10.0 } } }, through: june, currency: "usd")
      cents = described_class.new(days: { "mrr" => { "me/app" => { june => 0.4 } } }, through: june, currency: "usd")

      expect([ gone.above_zero?("mrr", "me/app"), gone.above_zero?("mrr", "me/app", may..june) ]).to eq([ false, true ])
      expect([ cents.above_zero?("mrr", "me/app"), cents.above_zero?("mrr", "me/app", may..june) ]).to eq([ false, false ])
    end

    it "writes money in its currency, and any other number with its thousands" do
      expect(counts.written(Progress::Numbers.find("mrr"), 4210.4)).to eq("$4,210")
      expect(counts.written(Progress::Numbers.find("customers"), 1230)).to eq("1,230")
      expect(counts.written(Progress::Numbers.find("commits"), 1230)).to eq("1,230")
    end
  end
end
