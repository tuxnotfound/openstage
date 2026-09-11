require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#safe_external_url" do
    it "passes through ordinary web addresses" do
      expect(helper.safe_external_url("https://example.com")).to eq("https://example.com")
      expect(helper.safe_external_url("http://example.com/x?y=1")).to eq("http://example.com/x?y=1")
    end

    it "drops anything that could execute script or read local files" do
      [
        "javascript:alert(1)", "JaVaScRiPt:alert(1)", "data:text/html,<script>alert(1)</script>",
        "vbscript:msgbox", "file:///etc/passwd", "//evil.example.com", "not a url at all"
      ].each do |bad|
        expect(helper.safe_external_url(bad)).to be_nil, "expected #{bad.inspect} to be dropped"
      end
    end

    it "handles blanks and malformed input without raising" do
      expect(helper.safe_external_url(nil)).to be_nil
      expect(helper.safe_external_url("")).to be_nil
      expect(helper.safe_external_url("http://[invalid")).to be_nil
    end
  end
end
