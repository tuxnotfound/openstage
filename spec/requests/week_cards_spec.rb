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
        expect(response.body).to include("Week 41 · Oct 5 – 11, 2026")
        expect(response.body).to include("openstage.dev/tux")
        expect(response.body).to include("1 commit in wheels-off")
        expect(response.body).to include("Serve the game at playwheelsoff.com")
      end
    end

    it "loads every card font, for the preview and for the download" do
      get "/week"

      CardText::FONTS.each do |font|
        expect(response.body).to include("font-family: '#{font[:family]}'; font-style: #{font[:style]}; font-weight: #{font[:weight]};")
      end
      expect(response.body).to match(/data-card-export-fonts-value="[^"]*newsreader-italic[^"]*\.woff2/)
    end

    it "opens a past week by its ISO name, and refuses a future or malformed one" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        get "/week/2026-W40"
        expect(response.body).to include("Week 40 · Sep 28 – Oct 4, 2026")

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
          layout: "active", theme: "dark", next_goal: "Launch on Product Hunt", time_zone: "Europe/Lisbon",
          sections: { "avatar" => "0", "streak" => "1" },
          headlines: { "2026-10-08" => { "text" => "playwheelsoff.com is live", "kind" => "shipped" } },
          post_text: "Week 41, my words."
        } }, headers: { "Accept" => "application/json" }
        expect(response.parsed_body).to eq("time_zone" => "Europe/Lisbon")

        card = WeekCard.find_by!(user: user, week_start: Date.new(2026, 10, 5))
        expect(card).to have_attributes(layout: "active", theme: "dark", next_goal: "Launch on Product Hunt",
                                        hidden_sections: [ "avatar" ], post_text: "Week 41, my words.")

        get "/week/2026-W41/preview"
        expect(response.body).to include("playwheelsoff.com is live")
        expect(response.body).to include("SHIPPED")
        expect(response.body).to include("Launch on Product Hunt")
        expect(response.body).to include(WeekCardsHelper::CARD_THEMES["dark"][:ground])
        expect(response.body).not_to include("<image")
      end
    end

    it "offers the days with a headline to lead with, and saves the pick" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        commit("Serve the game at playwheelsoff.com", "me/wheels-off", Time.zone.local(2026, 10, 8, 10))

        get "/week"
        expect(response.body).to include(%(<option value="">Automatic</option>))
        expect(response.body).to include(%(<option value="2026-10-08">Thu 8: 1 commit in wheels-off</option>))

        patch "/week/2026-W41", params: { week_card: { lead_on: "2026-10-08" } }, headers: { "Accept" => "application/json" }
        expect(WeekCard.find_by!(user: user).lead_on).to eq(Date.new(2026, 10, 8))

        patch "/week/2026-W41", params: { week_card: { lead_on: "2026-10-20" } }, headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "keeps no zone Rails does not know, and tells the editor so it does not redraw" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        patch "/week/2026-W41", params: { week_card: { time_zone: "Mars/Olympus" } }, headers: { "Accept" => "application/json" }
      end

      expect(response.parsed_body).to eq("time_zone" => nil)
    end

    it "starts a new week in the zone of the builder's last card" do
      WeekCard.create!(user: user, week_start: Date.new(2026, 9, 28), time_zone: "America/New_York")

      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        get "/week"
        expect(response.body).to include('value="America/New_York"')
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
