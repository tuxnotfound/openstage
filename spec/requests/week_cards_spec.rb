require "rails_helper"

RSpec.describe "Week cards", type: :request do
  let(:user) { create(:user, username: "tux", display_name: "Tux", github_username: "tuxnotfound") }

  def commit(title, repo, at)
    create(:entry, user: user, source: "github", entry_type: "shipped", title: title, repo_name: repo, occurred_at: at)
  end

  it "needs a signed-in builder" do
    get "/week"
    expect(response).to redirect_to(root_path)
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "opens this week's card, drawn from the builder's own work" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        commit("Serve the game at playwheelsoff.com", "me/wheels-off", 1.day.ago)

        expect { get "/week" }.to change { Event.named("card_opened").count }.by(1)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-week-card")
        expect(response.body).to include("WEEK 41 · OCT 5 – 11, 2026")
        expect(response.body).to include("openstage.dev/tux")
        expect(response.body).to include("1 commit in wheels-off")
        expect(response.body).to include("Serve the game at playwheelsoff.com")
      end
    end

    it "opens a past week by its ISO name, and refuses a future or malformed one" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        get "/week/2026-W40"
        expect(response.body).to include("WEEK 40 · SEP 28 – OCT 4, 2026")

        get "/week/2026-W50"
        expect(response).to redirect_to("/week")

        get "/week/2026-W99"
        expect(response).to have_http_status(:not_found)
      end
    end

    it "saves the builder's choices and headlines, and redraws the card with them" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        commit("Serve the game at playwheelsoff.com", "me/wheels-off", Time.zone.local(2026, 10, 8, 10))

        patch "/week/2026-W41", params: { week_card: {
          layout: "active",
          sections: { "avatar" => "0", "streak" => "1" },
          headlines: { "2026-10-08" => { "text" => "playwheelsoff.com is live", "kind" => "shipped" } },
          post_text: "Week 41, my words."
        } }, headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:no_content)

        card = WeekCard.find_by!(user: user, week_start: Date.new(2026, 10, 5))
        expect(card).to have_attributes(layout: "active", hidden_sections: [ "avatar" ], post_text: "Week 41, my words.")

        get "/week/2026-W41/preview"
        expect(response.body).to include("playwheelsoff.com is live")
        expect(response.body).to include("SHIPPED")
        expect(response.body).not_to include("<image")
      end
    end

    it "only ever touches the builder's own card" do
      other = create(:user)
      WeekCard.create!(user: other, week_start: Date.new(2026, 10, 5), post_text: "theirs")

      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        patch "/week/2026-W41", params: { week_card: { post_text: "mine" } }, headers: { "Accept" => "application/json" }
      end

      expect(WeekCard.find_by(user: other).post_text).to eq("theirs")
      expect(WeekCard.find_by(user: user).post_text).to eq("mine")
    end

    it "counts the editor opened from the weekly email" do
      expect { get "/week", params: { from: "weekly" } }.to change { Event.named("recap_from_email").count }.by(1)
    end

    it "accepts the download report from the browser" do
      expect { post "/recap/track", params: { name: "card_downloaded" }, as: :json }
        .to change { Event.named("card_downloaded").count }.by(1)
    end
  end
end
