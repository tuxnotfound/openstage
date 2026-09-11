require "rails_helper"

RSpec.describe ApplicationHelper, "#share_on_x_url", type: :helper do
  let(:user) { create(:user, username: "tuxnotfound") }

  it "builds the intent locally, with no network call" do
    entry = create(:entry, user: user, title: "Shipped the recap picker", body: nil)

    expect(Faraday).not_to receive(:get)
    url = helper.share_on_x_url(entry, user)

    expect(url).to start_with("https://twitter.com/intent/tweet?text=")
    expect(CGI.unescape(url)).to include("Shipped the recap picker")
  end

  it "anchors the link at the entry on the public profile" do
    entry = create(:entry, user: user)

    expect(CGI.unescape(helper.share_on_x_url(entry, user)))
      .to include("/tuxnotfound#entry-#{entry.id}")
  end

  it "includes a truncated body when there is one" do
    entry = create(:entry, user: user, title: "Title", body: "b" * 200)
    text = CGI.unescape(helper.share_on_x_url(entry, user))

    expect(text).to include("b" * 50)
    expect(text).not_to include("b" * 200)
  end
end
