require "rails_helper"

RSpec.describe "Entries", type: :request do
  let!(:user) { create(:user) }

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

  describe "POST /entries" do
    context "when not signed in" do
      it "redirects to root" do
        post entries_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "does not create an entry" do
        expect { post entries_path, params: valid_params }.not_to change(Entry, :count)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates an entry and redirects to dashboard" do
        expect { post entries_path, params: valid_params }.to change(Entry, :count).by(1)
        expect(response).to redirect_to(dashboard_path)
      end

      it "sets source to manual" do
        post entries_path, params: valid_params
        expect(Entry.last.source).to eq("manual")
      end

      it "does not create an entry with missing title" do
        invalid = valid_params.deep_merge(entry: { title: "" })
        expect { post entries_path, params: invalid }.not_to change(Entry, :count)
      end

      it "tags the entry with a project (repo_name)" do
        post entries_path, params: valid_params.deep_merge(entry: { repo_name: "me/openstage" })
        expect(Entry.last.repo_name).to eq("me/openstage")
      end

      it "leaves repo_name nil when the project field is blank" do
        post entries_path, params: valid_params.deep_merge(entry: { repo_name: "" })
        expect(Entry.last.repo_name).to be_nil
      end
    end
  end

  describe "PATCH /entries/:id" do
    let!(:entry) { create(:entry, user: user, hidden: false) }

    context "when not signed in" do
      it "redirects to root" do
        patch entry_path(entry), params: { hidden: true }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "hides an entry" do
        patch entry_path(entry), params: { hidden: true }
        expect(entry.reload.hidden).to be true
      end

      it "restores a hidden entry" do
        entry.update!(hidden: true)
        patch entry_path(entry), params: { hidden: false }
        expect(entry.reload.hidden).to be false
      end

      it "reassigns the project on a manual entry" do
        manual = create(:entry, user: user, source: "manual", entry_type: "note")
        patch entry_path(manual), params: { entry: { entry_type: "note", title: manual.title, occurred_at: manual.occurred_at, repo_name: "me/openstage" } }
        expect(manual.reload.repo_name).to eq("me/openstage")
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

    context "when signed in" do
      before { sign_in_as(user) }

      it "deletes the entry and redirects to dashboard" do
        entry = create(:entry, user: user)
        expect { delete entry_path(entry) }.to change(Entry, :count).by(-1)
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
