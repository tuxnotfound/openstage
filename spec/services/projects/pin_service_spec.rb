require "rails_helper"

RSpec.describe Projects::PinService do
  let(:user) { create(:user) }
  # Twelve projects on the stage, busiest first: p0 has 12 commits, p11 one.
  let!(:repos) do
    Array.new(12) do |i|
      create(:github_repo, user: user, name: "p#{i}", full_name: "me/p#{i}").tap do |repo|
        (12 - i).times { create(:entry, user: user, repo_name: repo.full_name) }
      end
    end
  end

  def pin(repo, pinned)
    described_class.new(repo: repo, pinned: pinned)
  end

  def pinned
    user.github_repos.pinned_names.sort_by { |name| name.delete("me/p").to_i }
  end

  it "unpins one of the busiest ten, which pins the other nine as they stand" do
    expect { pin(repos[3], false).call! }.to change { repos[0].reload.updated_at }

    expect(pinned).to eq((0..9).to_a.excluding(3).map { |i| "me/p#{i}" })
  end

  it "pins one more only while a colour is free, never swapping one out" do
    service = pin(repos[11], true)
    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "You can pin 10 projects at a time. Unpin one first." ])
    expect(pinned).to eq([])

    pin(repos[3], false).call!
    pin(repos[11], true).call!
    expect(pinned).to eq([ *(0..9).to_a.excluding(3), 11 ].map { |i| "me/p#{i}" })
    expect(pin(repos[3], true).call).to be(false)
  end

  it "keeps a pinned project pinned when asked again" do
    expect(pin(repos[0], true).call).to be(true)
    expect(pinned).to eq((0..9).map { |i| "me/p#{i}" })
  end

  it "goes back to the busiest once the last pin goes" do
    repos[11].update!(pinned: true)

    pin(repos[11], false).call!

    expect(pinned).to eq([])
  end

  it "needs a project" do
    expect(described_class.new(pinned: true).call).to be(false)
  end

  it "needs to know whether to pin it or unpin it" do
    service = pin(repos[0], nil)

    expect(service.call).to be(false)
    expect(service.errors[:pinned]).to be_present
  end

  it "pins only a project the stage shows" do
    hidden = create(:github_repo, user: user, name: "calc", full_name: "me/calc", included: false)
    service = pin(hidden, true)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Show calc on your stage before you pin it." ])
  end
end
