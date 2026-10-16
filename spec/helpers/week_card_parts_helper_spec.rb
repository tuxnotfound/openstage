require "rails_helper"

RSpec.describe WeekCardPartsHelper, type: :helper do
  describe "#card_repo_items" do
    def items(merged_prs: 0, releases: 0, deploys: 0, stars: 0)
      helper.card_repo_items(WeekCards::ExtrasService::Repos.new(merged_prs: merged_prs, releases: releases, deploys: deploys, stars: stars))
    end

    it "lists pull requests, releases, deploys and stars in that order, leaving zeros out" do
      expect(items(merged_prs: 2, releases: 3, deploys: 9, stars: 12))
        .to eq([ [ "2", "PRs merged" ], [ "3", "releases" ], [ "9", "deploys" ], [ "+12", "stars" ] ])
      expect(items(merged_prs: 1, deploys: 1)).to eq([ [ "1", "PR merged" ], [ "1", "deploy" ] ])
    end

    it "keeps two-digit counts clear of their neighbour, two to a row, on a card showing every cell" do
      weights = WeekCardsHelper::CELL_WEIGHTS
      cell = (WeekCardsHelper::CARD_RIGHT - WeekCardsHelper::CARD_LEFT) * weights[:repos] / weights.values.sum
      column = (cell - 32) / 2
      widths = items(merged_prs: 99, releases: 99, deploys: 99, stars: 99).map do |number, label|
        CardText.width(number, size: 13, weight: 700) + 4 + CardText.width(label, size: 13)
      end

      expect(widths).to all(be <= column - 8)
    end
  end
end
