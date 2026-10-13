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
        WeekCard.create!(user: user, week_start: Date.new(2026, 10, 5), style: "timeline")

        expect { get "/week" }.to change { Event.named("card_opened").count }.by(1)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-week-card")
        expect(response.body).to include("Week 41 · Oct 5 – 11, 2026")
        expect(response.body).to include("openstage.dev/tux")
        expect(response.body).to include("1 commit in wheels-off")
        expect(response.body).to include("Serve the game at playwheelsoff.com")
      end
    end

    it "offers each day's commits as a menu to start the words from, and no share link the card cannot ride on" do
      travel_to(Time.zone.local(2026, 10, 9, 12)) do
        commit("Serve the game at playwheelsoff.com", "me/wheels-off", 1.day.ago)

        get "/week"
        menu = Nokogiri::HTML(response.body).at_css("select[data-action='change->headline#pick']")
        expect(menu.css("option").map(&:text)).to eq([ "Fill in from a commit or post, then edit it…", "Serve the game at playwheelsoff.com" ])
        expect(menu["name"]).to be_nil
        expect(response.body).not_to include("x.com/intent", "bsky.app/intent")
        expect(response.body).to include("Copy post", "Download card")
      end
    end

    it "keeps the look in a toolbar and the rest in three tabs beside the card" do
      get "/week"
      page = Nokogiri::HTML(response.body)
      tabs = page.at_css("[data-controller='tabs']")
      panel = ->(key) { tabs.at_css("[data-tabs-panel='#{key}']") }

      expect(tabs.css("[role='tab']").map(&:text)).to eq([ "Words", "On the card", "Post" ])
      expect(tabs.css("input[name='week_card[style]'], input[name='week_card[theme]'], input[name='week_card[layout]']")).to be_empty
      expect(panel.call("words").css("input[name$='[text]']").size).to eq(7)
      expect(panel.call("words").at_css("#next_goal")).to be_present
      expect(panel.call("parts").at_css("#section_avatar")).to be_present
      expect(panel.call("post").at_css("#post_text")).to be_present
      expect(tabs.css("button[data-tabs-target='tab']").map { |button| button["type"] }.uniq).to eq([ "button" ])
    end

    it "loads every card font, for the preview and for the download" do
      get "/week"

      CardText::FONTS.each do |font|
        expect(response.body).to include("font-family: '#{font[:family]}'; font-style: #{font[:style]}; font-weight: #{font[:weight]};")
      end
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
          style: "timeline", layout: "active", theme: "dark", next_goal: "Launch on Product Hunt", time_zone: "Europe/Lisbon",
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

    describe "the template" do
      def page
        Nokogiri::HTML(response.body)
      end

      def offered?(css)
        page.at_css(css).attributes["hidden"].nil?
      end

      it "starts a new card on Changelog, and offers only Changelog's sections" do
        get "/week"

        expect(page.at_css("input[name='week_card[style]'][checked]")["value"]).to eq("changelog")
        expect(page.css("input[name='week_card[style]']").map { |radio| radio["value"] }).to eq(WeekCardTemplate.keys)
        expect(offered?("label:has(#section_activity)")).to be(true)
        expect(offered?("label:has(#section_history)")).to be(false)
        expect(offered?("label:has(#section_audience)")).to be(false)
        expect(page.at_css("label:has(#section_history)")["data-templates"]).to eq("star_chart")
        expect(page.at_css("#section_persona")).to be_nil
      end

      it "draws a new card as release notes" do
        travel_to(Time.zone.local(2026, 10, 9, 12)) do
          commit("Serve the game at playwheelsoff.com", "me/wheels-off", Time.zone.local(2026, 10, 8, 10))
          patch "/week/2026-W41", params: { week_card: { headlines: { "2026-10-08" => { "text" => "playwheelsoff.com is live", "kind" => "shipped" } } } },
                                  headers: { "Accept" => "application/json" }

          get "/week/2026-W41/preview"
          expect(response.body).to include(%(data-week-card="changelog"), "CHANGELOG · 2026.41", "playwheelsoff.com is live", "SHIPPED",
                                            "Mon, Tue, Wed, Fri, Sat, Sun · no changes", ".cf-inter-semibold{")
        end
      end

      it "hides the Days choice on Pixel Stage, which always draws seven days" do
        WeekCard.create!(user: user, week_start: Date.current.beginning_of_week, style: "pixel_stage")

        get "/week"
        expect(offered?("fieldset:has(input[name='week_card[layout]'])")).to be(false)
        expect(offered?("label:has(#section_building)")).to be(true)
      end

      it "saves the pick and draws the card with it" do
        patch "/week/2026-W41", params: { week_card: { style: "star_chart" } }, headers: { "Accept" => "application/json" }
        expect(WeekCard.find_by!(user: user).style).to eq("star_chart")

        get "/week/2026-W41/preview"
        expect(response.body).to include(%(data-week-card="star_chart"))

        patch "/week/2026-W41", params: { week_card: { style: "weekly_brief" } }, headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "keeps the sections a template hides when the builder switches" do
        patch "/week/2026-W41", params: { week_card: { style: "timeline", sections: { "audience" => "1", "code" => "0" } } },
                                headers: { "Accept" => "application/json" }
        patch "/week/2026-W41", params: { week_card: { style: "changelog" } }, headers: { "Accept" => "application/json" }

        expect(WeekCard.find_by!(user: user).hidden_sections).to eq([ "code" ])
      end

      it "gives the download only the chosen template's fonts" do
        get "/week"
        fonts = JSON.parse(page.at_css("[data-card-export-fonts-value]")["data-card-export-fonts-value"])

        expect(fonts.keys).to eq(WeekCardTemplate.keys)
        expect(fonts["changelog"].map { |font| font["family"] }.uniq).to contain_exactly("Inter", "DM Mono")
        expect(fonts["timeline"].map { |font| font["family"] }.uniq).to contain_exactly("DM Sans", "DM Mono")
        expect(fonts["pixel_stage"].map { |font| font["url"] }).to all(match(/(press-start-2p|pixelify-sans|tiny5)-\h+\.woff2/))
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
