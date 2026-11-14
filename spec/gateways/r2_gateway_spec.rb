require "rails_helper"
require "support/env_helper"

RSpec.describe R2Gateway do
  let(:head) { '<?xml version="1.0" encoding="UTF-8"?><ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Name>backups</Name>' }

  it "lists the keys under a prefix, sorted" do
    listing = "#{head}<IsTruncated>false</IsTruncated>" \
              "<Contents><Key>openstage/b.dump</Key></Contents><Contents><Key>openstage/a.dump</Key></Contents></ListBucketResult>"

    with_env(R2_TEST_SETTINGS) do
      stub_request(:get, %r{\Ahttps://r2\.test/backups\?.*prefix=openstage}).to_return(body: listing)

      expect(described_class.keys("openstage/")).to eq([ "openstage/a.dump", "openstage/b.dump" ])
    end
  end

  it "walks every page of a listing, because one stops at 1,000 keys" do
    first = "#{head}<IsTruncated>true</IsTruncated><NextContinuationToken>more</NextContinuationToken>" \
            "<Contents><Key>b.dump</Key></Contents></ListBucketResult>"
    second = "#{head}<IsTruncated>false</IsTruncated><Contents><Key>a.dump</Key></Contents></ListBucketResult>"

    with_env(R2_TEST_SETTINGS) do
      stub_request(:get, %r{\Ahttps://r2\.test/backups\?}).to_return(body: first)
      stub_request(:get, %r{\Ahttps://r2\.test/backups\?.*continuation-token=more}).to_return(body: second)

      expect(described_class.keys("")).to eq([ "a.dump", "b.dump" ])
    end
  end

  it "turns a refusal into Unauthorized" do
    with_env(R2_TEST_SETTINGS) do
      stub_request(:delete, "https://r2.test/backups/openstage/a.dump")
        .to_return(status: 403, body: "<Error><Code>AccessDenied</Code><Message>Access Denied</Message></Error>")

      expect { described_class.remove("openstage/a.dump") }.to raise_error(ApplicationGateway::Unauthorized)
    end
  end

  it "is configured only with all four settings" do
    with_env(R2_TEST_SETTINGS.merge("R2_BUCKET" => nil)) { expect(described_class).not_to be_configured }
    with_env(R2_TEST_SETTINGS) { expect(described_class).to be_configured }
  end
end
