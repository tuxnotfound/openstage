require "rails_helper"

# What an action answered (layouts/_flash): held at the top of the screen
# while the page scrolls, each with a way to dismiss it.
RSpec.describe "A page's messages", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def messages
    Nokogiri::HTML(response.body).css(".os-flash [data-flash-target='message']")
  end

  it "shows a success as a status with a button that dismisses it" do
    post "/entries", params: { entry: { entry_type: "shipped", title: "Shipped the thing", occurred_at: Time.current } }
    follow_redirect!

    message = messages.sole
    expect(message["role"]).to eq("status")
    expect(message.at_css("p").text).to eq("Entry posted.")
    expect(message.at_css("button[data-action='flash#dismiss']")["aria-label"]).to eq("Dismiss this message")
    expect(message.ancestors(".os-flash").first["data-controller"]).to eq("flash")
  end

  it "shows a refusal as an alert, dismissed the same way" do
    post "/entries", params: { entry: { entry_type: "shipped", title: "", occurred_at: Time.current } }
    follow_redirect!

    message = messages.sole
    expect(message["role"]).to eq("alert")
    expect(message["class"]).to include("down")
    expect(message.at_css("p").text).to include("Title")
    expect(message.at_css("button[data-action='flash#dismiss']")).to be_present
  end

  it "renders nothing when there is no message" do
    get "/dashboard" # takes the welcome that signing in left
    get "/dashboard"

    expect(Nokogiri::HTML(response.body).at_css(".os-flash")).to be_nil
  end
end
