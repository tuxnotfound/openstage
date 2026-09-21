require "rails_helper"

RSpec.describe "Event tracking", type: :request do
  let(:builder) { create(:user, github_username: "someone_else", username: "someone") }
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15" } }

  describe "seen" do
    it "records a signed-in user once per day, however many pages they load" do
      sign_in_as(builder)

      expect {
        get "/dashboard"
        get "/settings"
        get "/dashboard"
      }.to change { Event.named("seen").where(user: builder).count }.by(1)
    end

    it "records nothing for a signed-out visitor" do
      expect { get "/" }.not_to change { Event.named("seen").count }
    end
  end

  describe "ref_visit" do
    it "records a signed-out human arriving on a tagged link, once per session" do
      expect {
        get "/", params: { ref: "bio" }, headers: browser
        get "/", params: { ref: "recap" }, headers: browser
      }.to change { Event.named("ref_visit").count }.by(1)

      expect(Event.named("ref_visit").last.detail).to eq("bio")
    end

    it "ignores crawlers" do
      expect {
        get "/", params: { ref: "bio" }, headers: { "HTTP_USER_AGENT" => "GPTBot/1.0" }
      }.not_to change { Event.count }
    end

    it "ignores a signed-in builder checking their own link" do
      sign_in_as(builder)
      expect {
        get "/", params: { ref: "bio" }, headers: browser
      }.not_to change { Event.named("ref_visit").count }
    end
  end

  describe "recap events" do
    before do
      sign_in_as(builder)
      3.times do |i|
        create(:entry, user: builder, entry_type: "shipped", source: "github", title: "Commit #{i}",
                       repo_name: "someone/app", external_id: "sha#{i}", occurred_at: 1.day.ago)
      end
    end

    it "separates opening the picker from ticking a commit" do
      get "/recap"
      expect(Event.where(user: builder).pluck(:name)).to include("recap_opened")
      expect(Event.where(user: builder).pluck(:name)).not_to include("recap_picked")

      get "/recap", params: { picks: [ 1 ] }
      expect(Event.where(user: builder).pluck(:name)).to include("recap_picked")
    end

    it "records the quiet-week state as its own thing, not as an open" do
      builder.entries.destroy_all
      get "/recap"

      names = Event.where(user: builder).pluck(:name)
      expect(names).to include("recap_quiet")
      expect(names).not_to include("recap_opened")
    end

    it "accepts copy and compose reports from the page" do
      post "/recap/track", params: { name: "recap_copied" }, as: :json
      post "/recap/track", params: { name: "recap_intent", detail: "bluesky" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Event.find_by(user: builder, name: "recap_intent").detail).to eq("bluesky")
      expect(Event.where(user: builder, name: "recap_copied")).to exist
    end

    it "refuses any name a browser has no business claiming" do
      get "/recap" # the day's legitimate "seen" row lands here

      expect {
        post "/recap/track", params: { name: "seen" }, as: :json
        post "/recap/track", params: { name: "made_up" }, as: :json
      }.not_to change { Event.count }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "sends a signed-out report home" do
      reset!
      post "/recap/track", params: { name: "recap_copied" }, as: :json
      expect(response).to redirect_to(root_path)
    end
  end

  describe "returns on /admin" do
    let(:owner) { create(:user, github_username: "tuxnotfound", username: "tuxnotfound") }

    it "counts a later-day visit and a second-week visit separately, never the owner" do
      came_back = create(:user, username: "cameback", created_at: 10.days.ago)
      Event.create!(user: came_back, name: "seen", day: 10.days.ago.to_date, created_at: 10.days.ago)
      Event.create!(user: came_back, name: "seen", day: 2.days.ago.to_date, created_at: 2.days.ago)

      next_day = create(:user, username: "nextday", created_at: 3.days.ago)
      Event.create!(user: next_day, name: "seen", day: 2.days.ago.to_date, created_at: 2.days.ago)

      once = create(:user, username: "once", created_at: 9.days.ago)
      Event.create!(user: once, name: "seen", day: 9.days.ago.to_date, created_at: 9.days.ago)

      sign_in_as(owner)
      get "/admin"

      expect(response.body).to include('data-metric="returned" data-count="2"')
      expect(response.body).to include('data-metric="second-week" data-count="1"')
    end

    it "shows tagged visits and the recap funnel without the owner's own clicks" do
      Event.create!(name: "ref_visit", detail: "bio", day: Date.current, created_at: Time.current)
      Event.create!(user: builder, name: "recap_copied", day: Date.current, created_at: Time.current)

      sign_in_as(owner)
      get "/recap"
      get "/admin"

      expect(response.body).to include('data-ref-visit="bio" data-count="1"')
      expect(response.body).to include('data-recap-step="recap_copied" data-count="1"')
      expect(response.body).to include('data-recap-step="recap_opened" data-count="0"')
    end
  end
end
