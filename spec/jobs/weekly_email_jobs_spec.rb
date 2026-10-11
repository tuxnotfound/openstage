require "rails_helper"

RSpec.describe "Weekly email jobs", type: :job do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "fans out one job per active builder" do
    active = create(:user)
    create(:user, deleted_at: 1.day.ago)

    expect { WeeklyEmailFanoutJob.perform_now }.to have_enqueued_job(WeeklyEmailJob).with(active.id).exactly(:once)
  end

  it "sends one builder's emails" do
    user = create(:user, email: "b@example.com")
    3.times { |i| create(:entry, user: user, title: "Commit #{i}", occurred_at: 1.day.ago) }

    expect { WeeklyEmailJob.perform_now(user.id) }.to have_enqueued_mail(WeeklyMailer, :week_ready)
  end

  it "skips a builder deleted since the fanout" do
    user = create(:user, deleted_at: 1.hour.ago)

    expect { WeeklyEmailJob.perform_now(user.id) }.not_to have_enqueued_mail
  end
end
