require "rails_helper"

RSpec.describe Revenue::Book do
  let(:user) { create(:user, time_zone: "Europe/Paris") }
  let(:repo) { create(:github_repo, user: user) }
  let(:account) { user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.utc(2026, 11, 6, 23, 30)) }
  let(:book) { described_class.new(user) }

  def product(external_id, project = repo)
    account.revenue_products.create!(external_id: external_id, name: external_id, github_repo: project)
  end

  it "has nothing without an account" do
    expect(book.account).to be_nil
    expect(book.read_day).to be_nil
    expect(book.firsts).to eq({})
  end

  it "says the last day read, in the builder's zone" do
    account

    expect(book.read_day).to eq(Date.new(2026, 11, 7))
  end

  it "says the first day each project had revenue, from the products counted for it only" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    product("prod_b", nil).revenue_days.create!(day: Date.new(2026, 1, 1), currency: "usd", mrr: 100, subscriptions: 1)

    expect(book.firsts).to eq(repo.id => Date.new(2026, 5, 1))
  end

  it "reads a project's levels from a day on" do
    counted = product("prod_a")
    counted.revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    counted.revenue_days.create!(day: Date.new(2026, 6, 1), currency: "usd", mrr: 300, subscriptions: 2)

    expect(book.levels([ repo ]).mrr(repo.id).keys).to eq([ Date.new(2026, 5, 1), Date.new(2026, 6, 1) ])
    expect(book.levels([ repo ], from: Date.new(2026, 5, 15)).mrr(repo.id)).to eq(Date.new(2026, 6, 1) => 3.0)
  end
end
