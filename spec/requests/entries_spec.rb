require "rails_helper"

RSpec.describe "Entries", type: :request do
  describe "POST /entries" do
    let(:valid_params) do
      {
        entry: {
          entry_type: "milestone",
          title: "Launched v1",
          body: "First public release",
          url: "",
          occurred_at: Time.current
        }
      }
    end

    context "when not signed in" do
      it "redirects to root" do
        post entries_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "does not create an entry" do
        expect { post entries_path, params: valid_params }.not_to change(Entry, :count)
      end
    end
  end

  describe "DELETE /entries/:id" do
    context "when not signed in" do
      let!(:entry) { create(:entry) }

      it "redirects to root" do
        delete entry_path(entry)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
