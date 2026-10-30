require "rails_helper"

RSpec.describe Entries::SwitchService do
  let(:user) { create(:user, pro: true) }
  let(:entry) { create(:entry, user: user) }

  def switch(**switches)
    described_class.new(entry: entry, user: user, **switches)
  end

  it "hides an entry and restores it, as the form posts it" do
    expect(switch(hidden: "true").call).to be(true)
    expect(entry.reload.hidden).to be(true)

    switch(hidden: "false").call!
    expect(entry.reload.hidden).to be(false)
  end

  it "pins and unpins" do
    switch(pinned: "true").call!
    expect(entry.reload.pinned).to be(true)

    switch(pinned: "false").call!
    expect(entry.reload.pinned).to be(false)
  end

  it "makes an entry private and public again" do
    switch(visibility: "private").call!
    expect(entry.reload).to be_private_entry

    switch(visibility: "public").call!
    expect(entry.reload).to be_public_entry
  end

  it "refuses no switch, or two at once" do
    [ switch, switch(hidden: "true", pinned: "true") ].each do |service|
      expect(service.call).to be(false)
      expect(service.errors.full_messages).to eq([ "Pick one switch to flip." ])
    end
  end

  it "refuses a pin or a private entry on Free, and a fourth pin on Pro" do
    user.update!(pro: false)
    expect(switch(pinned: "true").tap(&:call).errors.full_messages).to eq([ "Pinning entries is a Pro feature." ])
    expect(switch(visibility: "private").tap(&:call).errors.full_messages).to eq([ "Private entries are a Pro feature." ])

    user.update!(pro: true)
    create_list(:entry, 3, user: user, pinned: true)
    expect(switch(pinned: "true").tap(&:call).errors.full_messages).to eq([ "You can pin up to 3 entries." ])
    expect(entry.reload.pinned).to be(false)
  end

  it "lets a Free builder unpin and make public what they set on Pro" do
    entry.update!(pinned: true, visibility: :private_entry)
    user.update!(pro: false)

    expect([ switch(pinned: "false").call, switch(visibility: "public").call ]).to eq([ true, true ])
    expect(entry.reload).to have_attributes(pinned: false, visibility: "public_entry")
  end
end
