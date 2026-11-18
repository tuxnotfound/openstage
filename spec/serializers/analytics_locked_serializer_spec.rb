require "rails_helper"

RSpec.describe AnalyticsLockedSerializer do
  it "sends a tab Free does not open as its line and the button to Pro, with the page's tabs and nothing of its numbers" do
    user = create(:user, pro: false)

    json = described_class.new(user, Analytics::Tab.find("mrr")).as_json

    expect(json).to eq("locked" => true, "tab" => "mrr", "tabs" => AnalyticsTabsSerializer.new(user).as_json["tabs"],
                       "pitch" => "Each project's MRR and paying customers, product by product, verified with Stripe.",
                       "checkout" => { "label" => "Go Pro for $7 a month", "path" => "/checkout" })
    expect(described_class.new(user, Analytics::Tab.find("openstage")).as_json["pitch"]).to eq("Views of your stage and your project pages, where they came from, and the links followed.")
  end
end
