require "rails_helper"

RSpec.describe Subscriptions::RequestService do
  let(:builder) { create(:user) }
  let(:repo) { create(:github_repo, user: builder) }

  it "asks a new reader to confirm a follow of one project" do
    service = described_class.new(user: builder, github_repo: repo, email: "Fan@Example.com")

    expect { expect(service.call).to be(true) }.to have_enqueued_mail(SubscriptionMailer, :confirm)
    expect(service.subscription).to have_attributes(github_repo: repo, email: "fan@example.com", confirmed_at: nil)
  end

  it "sends nothing to an address that already confirmed" do
    builder.subscriptions.create!(email: "fan@example.com", confirmed_at: Time.current)

    expect { described_class.new(user: builder, email: "fan@example.com").call }.not_to have_enqueued_mail
  end

  it "refuses an address that is not one" do
    service = described_class.new(user: builder, email: "nope")

    expect(service.call).to be(false)
    expect(service.errors[:email]).to be_present
  end

  it "refuses another builder's repo" do
    service = described_class.new(user: builder, github_repo: create(:github_repo), email: "fan@example.com")

    expect(service.call).to be(false)
    expect(service.errors[:github_repo]).to be_present
  end

  it "refuses without a builder" do
    expect(described_class.new(email: "fan@example.com").call).to be(false)
  end
end
