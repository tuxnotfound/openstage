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
end
