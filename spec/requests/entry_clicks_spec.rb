require "rails_helper"

RSpec.describe "EntryClicks", type: :request do
  let(:owner)   { create(:user) }
  let(:visitor) { create(:user) }
  let(:entry)   { create(:entry, user: owner, url: "https://example.com/post") }

  describe "GET /e/:id/out" do
    context "when entry exists and has a URL" do
      it "redirects to the entry URL" do
        get entry_click_out_path(entry)
        expect(response).to redirect_to("https://example.com/post")
      end

      it "records a click for anonymous visitors" do
        expect {
          get entry_click_out_path(entry)
        }.to change(EntryClick, :count).by(1)
      end

      it "records a click for signed-in non-owners" do
        sign_in_as(visitor)
        expect {
          get entry_click_out_path(entry)
        }.to change(EntryClick, :count).by(1)
      end

      it "does not record a click when the owner visits their own entry" do
        sign_in_as(owner)
        expect {
          get entry_click_out_path(entry)
        }.not_to change(EntryClick, :count)
      end
    end

    context "when entry has no URL" do
      let(:entry_no_url) { create(:entry, user: owner, url: nil) }

      it "redirects to root" do
        get entry_click_out_path(entry_no_url)
        expect(response).to redirect_to(root_path)
      end

      it "does not record a click" do
        expect {
          get entry_click_out_path(entry_no_url)
        }.not_to change(EntryClick, :count)
      end
    end

    context "when entry does not exist" do
      it "redirects to root" do
        get entry_click_out_path(0)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when entry URL has a non-http scheme" do
      let(:bad_entry) { create(:entry, user: owner, url: "javascript:alert(1)") }

      it "redirects to root without recording a click" do
        expect {
          get entry_click_out_path(bad_entry)
        }.not_to change(EntryClick, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when entry is private" do
      let(:private_entry) { create(:entry, user: owner, url: "https://example.com", visibility: "private") }

      it "redirects to root" do
        get entry_click_out_path(private_entry)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
