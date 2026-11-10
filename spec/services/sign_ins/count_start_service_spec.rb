require "rails_helper"

RSpec.describe SignIns::CountStartService do
  let(:browser) { "Mozilla/5.0 (Macintosh) Safari/605.1.15" }

  def count(session, user_agent: browser)
    described_class.new(session: session, user_agent: user_agent).call
    Event.named("sign_in_start").pluck(:detail)
  end

  it "counts a visitor's start by the tag they first came with, every click" do
    expect(count({ signup_ref: "reddit" })).to eq([ "reddit" ])
    expect(count({ signup_ref: "reddit" })).to eq(%w[reddit reddit])
  end

  it "counts a visitor who came with no tag as unattributed" do
    expect(count({})).to eq([ "unattributed" ])
  end

  it "never counts a signed-in click, nor a bot's" do
    expect(count({ user_id: 1, signup_ref: "reddit" })).to eq([])
    expect(count({}, user_agent: "Googlebot/2.1")).to eq([])
  end
end
