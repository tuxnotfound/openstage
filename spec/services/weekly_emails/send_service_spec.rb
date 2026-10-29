require "rails_helper"

RSpec.describe WeeklyEmails::SendService do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  # A Friday send: Week 43 runs Mon Oct 19 to today.
  before { travel_to Time.utc(2026, 10, 23, 13) }

  let(:builder) { create(:user, email: "builder@example.com") }

  def ship(count, user: builder, at: 1.day.ago)
    count.times { |i| create(:entry, user: user, title: "Commit #{i}", repo_name: "me/app", occurred_at: at) }
  end

  def subscriber(email, confirmed: true)
    builder.subscriptions.create!(email: email, confirmed_at: (Time.current if confirmed))
  end

  it "mails the builder and each confirmed subscriber on a week worth posting" do
    ship(3)
    reader = subscriber("reader@example.com")
    subscriber("pending@example.com", confirmed: false)

    service = described_class.new(user: builder)
    expect { service.call! }
      .to have_enqueued_mail(WeeklyMailer, :week_ready).with(builder)
      .and have_enqueued_mail(WeeklyMailer, :digest).with(reader).exactly(:once)

    expect(service.builder_mailed).to be(true)
    expect(service.digests_sent).to eq(1)
  end

  describe "a project's followers" do
    let(:repo) { create(:github_repo, user: builder, name: "app", full_name: "me/app") }

    def follower(email)
      builder.subscriptions.create!(email: email, github_repo: repo, confirmed_at: Time.current)
    end

    it "get that project's week, unless they follow the whole page already" do
      ship(3)
      fan = follower("fan@example.com")
      subscriber("both@example.com")
      follower("both@example.com")

      service = described_class.new(user: builder)
      expect { service.call! }.to have_enqueued_mail(WeeklyMailer, :digest).with(fan).exactly(:once)
      expect(service.digests_sent).to eq(2)
    end

    it "get nothing when their project had a quiet week" do
      ship(3, at: 1.day.ago)
      builder.entries.update_all(repo_name: "me/other")
      create(:entry, user: builder, repo_name: "me/app", occurred_at: 1.day.ago)
      follower("fan@example.com")

      service = described_class.new(user: builder)
      service.call!
      expect(service.digests_sent).to eq(0)
    end

    # Each quiet check reads three times: when the work in view began, in one
    # MIN, the week's commits by day and its shipped and published entries.
    # Ranking the builder's projects would read their whole history again
    # for every project followed.
    it "are judged without ranking the builder's projects" do
      ship(3)
      create(:entry, user: builder, repo_name: "me/other", occurred_at: 1.year.ago)
      follower("fan@example.com")
      reads = []
      counter = ->(*, payload) { reads << payload[:sql] if payload[:sql].include?('FROM "entries"') && !payload[:cached] }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.new(user: builder).call! }

      expect(reads.grep(/GROUP BY "entries"\."repo_name"/)).to be_empty
      expect(reads.size).to eq(6), reads.join("\n")
    end
  end

  it "sends nothing on a quiet week" do
    ship(2)
    subscriber("reader@example.com")

    expect { described_class.new(user: builder).call! }.not_to have_enqueued_mail
  end

  it "judges the week the emails show, not the last seven days" do
    ship(3, at: Time.utc(2026, 10, 17, 12))
    subscriber("reader@example.com")

    expect { described_class.new(user: builder).call! }.not_to have_enqueued_mail
  end

  it "counts shipped and published entries with the commits" do
    ship(1)
    create(:entry, user: builder, entry_type: "milestone", source: "manual", occurred_at: 2.days.ago)
    create(:entry, user: builder, entry_type: "note", source: "manual", occurred_at: 2.days.ago)

    expect { described_class.new(user: builder).call! }.to have_enqueued_mail(WeeklyMailer, :week_ready)
  end

  it "still sends the digest to subscribers of a builder who turned their email off" do
    builder.update!(weekly_email: false)
    ship(3)
    subscriber("reader@example.com")

    service = described_class.new(user: builder)
    expect { service.call! }.to have_enqueued_mail(WeeklyMailer, :digest).exactly(:once)
    expect(service.builder_mailed).to be(false)
  end

  it "skips the builder's email when GitHub gave no address" do
    builder.update!(email: nil)
    ship(3)

    expect { described_class.new(user: builder).call! }.not_to have_enqueued_mail(WeeklyMailer, :week_ready)
  end

  it "mails nobody twice in the same week, and again the next week" do
    ship(3)
    subscriber("reader@example.com")
    described_class.new(user: builder).call!

    expect { described_class.new(user: builder).call! }.not_to have_enqueued_mail

    travel_to(7.days.from_now) do
      ship(3)
      expect { described_class.new(user: builder).call! }
        .to have_enqueued_mail(WeeklyMailer, :week_ready).and have_enqueued_mail(WeeklyMailer, :digest)
    end
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
  end
end
