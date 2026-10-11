require "rails_helper"

RSpec.describe WeekCardsHelper, type: :helper do
  describe "#card_lines" do
    it "breaks between words to fit the column" do
      expect(helper.card_lines("Serve the game at playwheelsoff.com, workers.dev off", chars: 20, max_lines: 4))
        .to eq([ "Serve the game at", "playwheelsoff.com,", "workers.dev off" ])
    end

    it "ends a headline that runs over with an ellipsis" do
      lines = helper.card_lines("one two three four five six seven", chars: 9, max_lines: 2)
      expect(lines.size).to eq(2)
      expect(lines.last).to end_with("…")
    end

    it "cuts a single word longer than the column" do
      expect(helper.card_lines("x" * 30, chars: 10, max_lines: 3).first.length).to be <= 10
    end
  end

  it "never lets one commit stand taller than ten pixels" do
    days = [ Struct.new(:total).new(2), Struct.new(:total).new(1) ]
    expect(helper.card_bar_scale(days)).to eq(10)
  end
end
