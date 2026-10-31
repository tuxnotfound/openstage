require "rails_helper"

RSpec.describe SiteVisitCount do
  let!(:repo) { create(:github_repo) }
  let(:day) { Date.new(2026, 10, 25) }

  def counts(kind)
    repo.site_visit_counts.where(kind: kind).pluck(:value, :count).sort
  end

  describe ".add" do
    it "adds one to each value of the day, by kind, in one statement" do
      statements = []
      ActiveSupport::Notifications.subscribed(->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }, "sql.active_record") do
        described_class.add(repo.id, day, { "page" => "/pricing", "source" => "news.ycombinator.com", "ref" => "hn", "country" => "PT" })
      end
      described_class.add(repo.id, day, { "page" => "/pricing" })

      expect(statements.size).to eq(1)
      expect(repo.site_visit_counts.pluck(:kind, :value, :count)).to contain_exactly(
        [ "page", "/pricing", 2 ], [ "source", "news.ycombinator.com", 1 ], [ "ref", "hn", 1 ], [ "country", "PT", 1 ]
      )
    end

    it "counts a new value as Other once its kind has its day's cap of values, and keeps counting the ones it has" do
      stub_const("#{described_class}::CAPS", { "page" => 2, "source" => 1, "ref" => 1 })
      %w[/a /b /c /d /a].each { |path| described_class.add(repo.id, day, { "page" => path }) }
      %w[github.com reddit.com].each { |host| described_class.add(repo.id, day, { "source" => host }) }
      described_class.add(repo.id, day + 1, { "page" => "/e" })

      expect(counts("page")).to eq([ [ "(other)", 2 ], [ "/a", 2 ], [ "/b", 1 ], [ "/e", 1 ] ])
      expect(counts("source")).to eq([ [ "(other)", 1 ], [ "github.com", 1 ] ])
    end

    it "counts a new value as Other from a visitor no longer fresh, and keeps counting the values the day has" do
      described_class.add(repo.id, day, { "page" => "/a" })
      described_class.add(repo.id, day, { "page" => "/a" }, fresh: false)
      described_class.add(repo.id, day, { "page" => "/b", "country" => "PT" }, fresh: false)

      expect([ counts("page"), counts("country") ]).to eq([ [ [ "(other)", 1 ], [ "/a", 2 ] ], [ [ "PT", 1 ] ] ])
    end

    it "keeps the totals right past the caps, and never caps countries" do
      stub_const("#{described_class}::CAPS", { "page" => 3, "source" => 3, "ref" => 3 })
      codes = %w[PT ES FR DE IT NL BE]
      codes.each_with_index { |code, i| described_class.add(repo.id, day, { "page" => "/#{i}", "country" => code }) }

      expect(repo.site_visit_counts.where(kind: "page").sum(:count)).to eq(7)
      expect(counts("country").map(&:first)).to match_array(codes)
    end

    it "keeps each project's days apart" do
      other = create(:github_repo)
      described_class.add(repo.id, day, { "page" => "/" })
      described_class.add(other.id, day, { "page" => "/" })
      described_class.add(repo.id, day + 1, { "page" => "/" })

      expect(described_class.pluck(:github_repo_id, :day, :count)).to contain_exactly([ repo.id, day, 1 ], [ repo.id, day + 1, 1 ], [ other.id, day, 1 ])
    end

    it "writes nothing for no values" do
      expect { described_class.add(repo.id, day, {}) }.not_to change(described_class, :count)
    end

    it "takes a value as it is, quotes and colons included" do
      described_class.add(repo.id, day, { "page" => "/it's/:day/?" })

      expect(counts("page")).to eq([ [ "/it's/:day/?", 1 ] ])
    end
  end
end
