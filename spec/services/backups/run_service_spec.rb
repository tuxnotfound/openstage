require "rails_helper"
require "support/env_helper"

RSpec.describe Backups::RunService do
  let(:listing_head) { '<?xml version="1.0" encoding="UTF-8"?><ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Name>backups</Name>' }

  it "uploads a pg_dump of the database and leaves no copy behind" do
    with_env(R2_TEST_SETTINGS) do
      upload = stub_request(:put, %r{\Ahttps://r2\.test/backups/openstage/test/test-\d{8}-\d{4}\.dump\z})
      stub_request(:get, %r{\Ahttps://r2\.test/backups\?.*list-type=2})
        .to_return(body: "#{listing_head}<IsTruncated>false</IsTruncated></ListBucketResult>")
      service = described_class.new

      expect(service.call).to be_truthy
      expect(upload).to have_been_requested
      expect(service.key).to start_with("openstage/test/")
      expect(Dir.glob(Rails.root.join("tmp/test-*.dump"))).to be_empty
    end
  end

  it "keeps the newest 30 copies and deletes the older ones" do
    keys = (1..31).map { |day| "<Contents><Key>openstage/test/test-202611#{format("%02d", day)}-0245.dump</Key></Contents>" }
    with_env(R2_TEST_SETTINGS) do
      stub_request(:put, %r{\Ahttps://r2\.test/backups/openstage/test/})
      stub_request(:get, %r{\Ahttps://r2\.test/backups\?.*list-type=2})
        .to_return(body: "#{listing_head}<IsTruncated>false</IsTruncated>#{keys.join}</ListBucketResult>")
      oldest = stub_request(:delete, "https://r2.test/backups/openstage/test/test-20261101-0245.dump")

      described_class.new.call!

      expect(oldest).to have_been_requested
      expect(a_request(:delete, %r{\Ahttps://r2\.test/})).to have_been_made.once
    end
  end

  it "refuses to run without R2" do
    with_env(R2_TEST_SETTINGS.transform_values { nil }) do
      service = described_class.new

      expect(service.call).to be_falsey
      expect(service.errors[:base]).to include("R2 is not configured, so nothing would leave the box")
    end
  end
end
