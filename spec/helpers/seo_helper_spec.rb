require "rails_helper"

RSpec.describe SeoHelper, "#meta_description", type: :helper do
  it "keeps a description of 160 characters or fewer as it is" do
    helper.content_for(:meta_description, "A shopping list priced at each Portuguese supermarket.")

    expect(helper.meta_description).to eq("A shopping list priced at each Portuguese supermarket.")
  end

  it "cuts a longer one on a word, within 160 characters" do
    helper.content_for(:meta_description, "#{'skate ' * 40}town")

    expect(helper.meta_description.length).to be <= 160
    expect(helper.meta_description).to end_with("skate…")
  end

  it "neither splits nor escapes twice what content_for escaped" do
    helper.content_for(:meta_description, "#{'a' * 150} Tom & Jerry")

    expect(helper.meta_description).to eq("#{'a' * 150} Tom &…")
    expect(helper.meta_description).not_to include("&amp;")
  end

  it "falls back to the site's description" do
    expect(helper.meta_description).to eq(SeoHelper::DEFAULT_DESCRIPTION)
  end
end
