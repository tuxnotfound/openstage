require "rails_helper"

RSpec.describe AvatarGateway do
  describe ".image" do
    it "fetches the avatar at the size asked for, keeping GitHub's own query" do
      stub_request(:get, "https://avatars.githubusercontent.com/u/42?v=4&s=192")
        .to_return(status: 200, headers: { "Content-Type" => "image/png" }, body: "PNGBYTES")

      expect(described_class.image("https://avatars.githubusercontent.com/u/42?v=4", size: 192)).to eq("PNGBYTES")
    end

    it "fetches nothing from any other address" do
      expect(described_class.image("https://example.com/me.png", size: 192)).to be_nil
      expect(described_class.image("http://avatars.githubusercontent.com/u/42", size: 192)).to be_nil
      expect(described_class.image("not a url", size: 192)).to be_nil
      expect(described_class.image(nil, size: 192)).to be_nil
    end

    it "raises when GitHub has no such avatar" do
      stub_request(:get, "https://avatars.githubusercontent.com/u/0?s=192").to_return(status: 404)

      expect { described_class.image("https://avatars.githubusercontent.com/u/0", size: 192) }.to raise_error(ApplicationGateway::NotFound)
    end
  end
end
