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
