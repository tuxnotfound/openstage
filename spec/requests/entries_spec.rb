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
        expect(response).to redirect_to(dashboard_path(tab: "entries", anchor: "entries"))
      end

      it "remembers a deleted commit so the sync never brings it back" do
        commit = create(:entry, user: user, source: "github", external_id: "abc123")
        note = create(:entry, user: user, source: "manual", entry_type: "note")

        delete entry_path(commit)
        delete entry_path(note)

        expect(DismissedCommit.where(user: user).pluck(:sha)).to eq([ "abc123" ])
      end
    end
  end

  # The dashboard's row buttons, as Turbo sends them: each answers with the
  # streams that redraw only what the click changed, so the page never
  # reloads or shows "Content missing". Without JavaScript they redirect.
  describe "a click on a dashboard row" do
    let(:stream) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }
    let!(:commit) { create(:entry, user: user, title: "Fix the login", occurred_at: 1.hour.ago) }
    let!(:note) { create(:entry, user: user, source: "manual", entry_type: "note", title: "Wrote a note", occurred_at: 2.hours.ago) }

    before { sign_in_as(user) }

    def streams
      Nokogiri::HTML(response.body).css("turbo-stream").map { |node| [ node["action"], node["target"] ] }
    end

    def template(target)
      Nokogiri::HTML(response.body).at_css("turbo-stream[target='#{target}'] template")&.inner_html.to_s
    end

    it "hides a commit in place: it leaves Commits, Hidden takes it with its switch off, the counts follow" do
      patch entry_path(commit), params: { hidden: true, list: "commits", q: "", repo: "" }, headers: stream

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(commit.reload.hidden).to be(true)
      expect(streams).to eq([ [ "replace", "entries-tabs" ], [ "replace", "entries-news" ], [ "replace", "entries-commits" ],
                              [ "replace", "entries-hidden" ], [ "replace", "entries-private" ] ])
      expect(Nokogiri::HTML(template("entries-tabs")).css("a").map(&:text)).to eq([ "What's new 1", "Commits 0", "Hidden 1" ])
      hidden = Nokogiri::HTML(template("entries-hidden"))
      expect(hidden.text).to include("Fix the login")
      expect(hidden.at_css("button[role='switch']").attributes.transform_values(&:value))
        .to include("aria-checked" => "false", "aria-label" => "Show Fix the login on your stage")
    end

    it "restores a row from Hidden in place, and Commits gets it back" do
      commit.update!(hidden: true)
      patch entry_path(commit), params: { hidden: false, list: "hidden" }, headers: stream

      expect(commit.reload.hidden).to be(false)
      expect(streams).to include([ "replace", "entries-hidden" ], [ "replace", "entries-commits" ])
      expect(Nokogiri::HTML(template("entries-tabs")).css("a").map(&:text)).to eq([ "What's new 1", "Commits 1", "Hidden 0" ])
      expect(template("entries-commits")).to include("Fix the login")
      expect(template("entries-hidden")).to include("Nothing here now.")
    end

    it "keeps the search on the lists a click redraws" do
      commit.update!(hidden: true)
      patch entry_path(commit), params: { hidden: false, list: "hidden", q: "login" }, headers: stream

      expect(template("entries-commits")).to include("Fix the login", "1 entry of 1")
      expect(template("entries-news")).to include("No entries match that.")
    end

    it "redraws a row that stays as a pin changes it, and moves one made private to Private" do
      user.update!(pro: true)
      create(:entry, user: user, source: "manual", entry_type: "milestone", title: "Shipped v1", occurred_at: 3.hours.ago)
      patch entry_path(note), params: { pinned: "true", list: "news" }, headers: stream
      expect(note.reload.pinned?).to be(true)
      expect(streams).to include([ "replace", "entry_#{note.id}" ])
      expect(template("entry_#{note.id}")).to include("Unpin from your stage", "Pinned")

      patch entry_path(note), params: { visibility: "private", list: "news" }, headers: stream
      expect(note.reload).to be_private_entry
      expect(streams).to include([ "remove", "entry_#{note.id}" ], [ "replace", "entries-private" ])
      expect(template("entries-private")).to include("Wrote a note")
    end

    it "says on the row why a click was refused, and changes nothing else" do
      user.update!(pro: true)
      create_list(:entry, 3, user: user, pinned: true)
      patch entry_path(note), params: { pinned: "true", list: "news" }, headers: stream

      expect(note.reload.pinned?).to be(false)
      expect(streams).to eq([ [ "replace", "entry_#{note.id}" ] ])
      expect(template("entry_#{note.id}")).to include("You can pin up to 3 entries.")
    end

    it "deletes a row in place" do
      create(:entry, user: user, source: "manual", entry_type: "milestone", title: "Shipped v1", occurred_at: 3.hours.ago)
      delete entry_path(note), params: { list: "news" }, headers: stream

      expect(Entry.exists?(note.id)).to be(false)
      expect(streams).to include([ "remove", "entry_#{note.id}" ], [ "replace", "entries-tabs" ])
    end

    it "redraws the list whole once its last row leaves, so it says it is empty" do
      patch entry_path(commit), params: { hidden: true, list: "commits", q: "login" }, headers: stream

      expect(streams).to include([ "replace", "entries-commits" ])
      expect(template("entries-commits")).to include("No entries match that.")
    end

    it "saves an edit in place and gives Cancel the row back in its frame" do
      patch entry_path(note), params: { entry: { entry_type: "note", title: "A better note", occurred_at: note.occurred_at }, list: "news" },
                              headers: stream
      expect(template("entry_#{note.id}")).to include("A better note")

      get entry_path(note), headers: { "Turbo-Frame" => "entry_#{note.id}" }
      expect(Nokogiri::HTML(response.body).at_css("turbo-frame#entry_#{note.id}").text).to include("A better note")

      get entry_path(note)
      expect(response).to redirect_to(dashboard_path)
    end

    it "redirects without JavaScript to the list and the search the click came from" do
      commit.update!(hidden: true)
      patch entry_path(commit), params: { hidden: false, list: "hidden", q: "login", repo: "" }

      expect(response).to redirect_to(dashboard_path(q: "login", tab: "entries", list: "hidden", anchor: "entries"))
      expect(commit.reload.hidden).to be(false)
    end
  end
end
