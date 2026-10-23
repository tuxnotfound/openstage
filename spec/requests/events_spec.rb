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

  describe "from the cards in the browser" do
    before { sign_in_as(builder) }

    it "records a name a browser may claim, with a detail from its list" do
      post "/events", params: { name: "progress_card_downloaded", detail: "lines" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Event.named("progress_card_downloaded").last).to have_attributes(user_id: builder.id, detail: "lines")
    end

    it "drops a detail off the list and refuses any other name" do
      post "/events", params: { name: "recap_intent", detail: "myspace" }, as: :json
      expect(Event.named("recap_intent").last.detail).to eq("")

      expect { post "/events", params: { name: "seen" }, as: :json }.not_to change(Event, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "sends a signed-out report home" do
      reset!
      post "/events", params: { name: "recap_copied" }, as: :json

      expect(response).to redirect_to(root_path)
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
