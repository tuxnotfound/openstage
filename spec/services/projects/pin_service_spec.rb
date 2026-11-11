require "rails_helper"

RSpec.describe Projects::PinService do
  let(:user) { create(:user) }
  let(:repo) { create(:github_repo, user: user, name: "calc", full_name: "me/calc") }

  it "pins a project to its builder's stage, and unpins it" do
    described_class.new(repo: repo, pinned: true).call!
    expect(repo.reload.pinned).to be(true)

    described_class.new(repo: repo, pinned: false).call!
    expect(repo.reload.pinned).to be(false)
  end

  it "needs a project" do
    expect(described_class.new(pinned: true).call).to be(false)
  end

  it "needs to know whether to pin it or unpin it" do
    service = described_class.new(repo: repo, pinned: nil)

    expect(service.call).to be(false)
    expect(service.errors[:pinned]).to be_present
  end

  it "pins only a project the stage shows" do
    repo.update!(included: false)
    service = described_class.new(repo: repo, pinned: true)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Show calc on your stage before you pin it." ])
    expect(repo.reload.pinned).to be(false)
  end

  it "pins as many as the palette has colours, counting those with work on Openstage, and still unpins or keeps one of them" do
    ten = create_list(:github_repo, 10, user: user, pinned: true).each { |pinned| create(:entry, user: user, repo_name: pinned.full_name) }
    create(:github_repo, user: user, pinned: true)
    service = described_class.new(repo: repo, pinned: true)

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "10 projects are pinned, one per colour. Unpin one to pin calc." ])
    expect(described_class.new(repo: ten.first, pinned: true).call).to be(true)
    expect(described_class.new(repo: ten.first, pinned: false).call).to be(true)
    expect(described_class.new(repo: repo, pinned: true).call).to be(true)
  end
end
