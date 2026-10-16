require "rails_helper"

RSpec.describe Progress::RunIn do
  let(:body) { "- Trained on me is live!!\n\nopenstage\n- UI cleanup\n- Landing page redesign" }

  it "continues a title ending in a colon into its body, without bullets, blanks or project names" do
    expect(described_class.of("This week's build log:", body, %w[openstage wheels-off]))
      .to eq("Trained on me is live!! · UI cleanup · Landing page redesign")
  end

  it "drops a body line that repeats the title" do
    expect(described_class.of("Shipped this week:", "Shipped this week:\n- A recap", [])).to eq("A recap")
  end

  it "has nothing to add without a colon or a body" do
    expect(described_class.of("We are live!!", body, [])).to eq("")
    expect(described_class.of("Shipped this week:", nil, [])).to eq("")
  end

  it "caps a run-in at a word, never inside one" do
    text = "word " * 40

    expect(described_class.capped(text.strip, 22)).to eq("word word word word…")
    expect(described_class.capped("short", 22)).to eq("short")
  end
end
