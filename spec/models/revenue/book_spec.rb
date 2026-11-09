require "rails_helper"

RSpec.describe Revenue::Book do
  let(:user) { create(:user, time_zone: "Europe/Paris") }
  let(:repo) { create(:github_repo, user: user) }
  let(:account) { user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok", read_at: Time.utc(2026, 11, 6, 23, 30), read_through: Date.new(2026, 11, 6)) }
  let(:book) { described_class.new(user) }

  before { travel_to Time.utc(2026, 11, 7, 12) }

  def product(external_id, project = repo)
    account.revenue_products.create!(external_id: external_id, name: external_id, github_repo: project)
  end

  it "has nothing without an account" do
    expect(book.account).to be_nil
    expect(book.read_day).to be_nil
    expect(book.firsts).to eq({})
  end

  it "says the last day the read counted, even where its time falls on another day in the builder's zone now" do
    account

    expect(book.read_day).to eq(Date.new(2026, 11, 6))
  end

  it "says the first day each project had revenue, from the products counted for it only" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    product("prod_b", nil).revenue_days.create!(day: Date.new(2026, 1, 1), currency: "usd", mrr: 100, subscriptions: 1)

    expect(book.firsts).to eq(repo.id => Date.new(2026, 5, 1))
  end

  it "holds nothing for the pages while Stripe refuses the key" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    account.update!(refused_at: Time.current)

    expect(book).not_to be_live
    expect(book.firsts).to eq({})
  end

  it "holds nothing for the pages once reads have failed for three days, until one works" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)

    travel_to account.read_at + 3.days - 1.minute
    expect(described_class.new(user)).to be_live

    travel_to account.read_at + 3.days + 1.minute
    expect(described_class.new(user)).not_to be_live
    expect(described_class.new(user).firsts).to eq({})

    account.update!(read_at: Time.current)
    expect(described_class.new(user).firsts).to eq(repo.id => Date.new(2026, 5, 1))
  end

  it "holds nothing for the pages when no read has worked for three days since connecting" do
    account.update!(read_at: nil, read_through: nil, created_at: 4.days.ago)

    expect(book).not_to be_live
  end

  it "names the projects with revenue, and each one's first day for both numbers" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    create(:github_repo, user: user)

    expect(book.repos).to eq([ repo ])
    expect(book.first_days).to eq("mrr" => { repo.full_name => Date.new(2026, 5, 1) }, "customers" => { repo.full_name => Date.new(2026, 5, 1) })
  end

  it "keeps the currency of revenue that ended before the day asked for" do
    product("prod_a").revenue_days.create!(day: Date.new(2026, 5, 1), currency: "eur", mrr: 100, subscriptions: 1)

    levels = book.levels([ repo ], from: Date.new(2026, 10, 1))

    expect(levels.currency).to eq("eur")
    expect(levels.mrr(repo.id)).to eq({})
  end

  it "reads a project's levels from a day on" do
    counted = product("prod_a")
    counted.revenue_days.create!(day: Date.new(2026, 5, 1), currency: "usd", mrr: 100, subscriptions: 1)
    counted.revenue_days.create!(day: Date.new(2026, 6, 1), currency: "usd", mrr: 300, subscriptions: 2)

    expect(book.levels([ repo ]).mrr(repo.id).keys).to eq([ Date.new(2026, 5, 1), Date.new(2026, 6, 1) ])
    expect(book.levels([ repo ], from: Date.new(2026, 5, 15)).mrr(repo.id)).to eq(Date.new(2026, 6, 1) => 3.0)
  end

  describe "a project's paying customers" do
    let(:day) { Date.new(2026, 11, 6) }
    let(:other) { create(:github_repo, user: user) }

    def paying(*products, customers:, on: day)
      account.revenue_customer_days.create!(day: on, product_ids: products.map(&:id).sort, customers: customers)
    end

    it "counts a customer of two of its products once" do
      a = product("prod_a")
      b = product("prod_b")
      paying(a, customers: 2)
      paying(b, customers: 1)
      paying(a, b, customers: 4)

      expect(book.levels([ repo ]).customers(repo.id)).to eq(day => 7)
    end

    it "counts a customer of two projects once for each, and leaves out products no project counts" do
      a = product("prod_a")
      b = product("prod_b", other)
      c = product("prod_c", nil)
      paying(a, b, customers: 3)
      paying(c, customers: 9)

      levels = book.levels([ repo, other ])

      expect(levels.customers(repo.id)).to eq(day => 3)
      expect(levels.customers(other.id)).to eq(day => 3)
    end

    it "follows a product moved to another project, with no read" do
      a = product("prod_a")
      b = product("prod_b")
      paying(a, b, customers: 4)

      b.update!(github_repo: other)

      levels = described_class.new(user).levels([ repo, other ])
      expect(levels.customers(repo.id)).to eq(day => 4)
      expect(levels.customers(other.id)).to eq(day => 4)
    end

    it "reads them from a day on" do
      a = product("prod_a")
      paying(a, customers: 1, on: day - 1)
      paying(a, customers: 2)

      expect(book.levels([ repo ], from: day).customers(repo.id)).to eq(day => 2)
    end
  end
end
