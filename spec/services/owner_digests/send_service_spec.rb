require "rails_helper"

RSpec.describe OwnerDigests::SendService do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  let!(:owner) { create(:user, github_username: "tuxnotfound", username: "tuxnotfound", created_at: 2.days.ago) }

  it "counts the week's strangers, leaving me and older signups out" do
    stranger = create(:user, signup_ref: "peerlist", created_at: 1.day.ago)
    create(:entry, user: stranger)
    create(:user, signup_ref: "direct", created_at: 3.days.ago)
    create(:user, signup_ref: "launch", created_at: 10.days.ago)
    Event.track("recap_intent", user: stranger)
    Event.track("recap_intent", user: owner)

    service = described_class.new
    expect { service.call! }.to have_enqueued_mail(SystemMailer, :owner_digest)

    expect(service.numbers).to include(
      signups_by_ref: { "peerlist" => 1, "direct" => 1 },
      activated: 1,
      recap_intents: 1,
      failed_jobs: 0
    )
  end

  it "reports failed jobs by class" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "WeeklyEmailJob", arguments: {})
    SolidQueue::FailedExecution.create!(job: job, exception: RuntimeError.new("boom"))

    service = described_class.new
    service.call!

    expect(service.numbers).to include(failed_jobs: 1, failed_job_classes: { "WeeklyEmailJob" => 1 })
  end

  it "renders a mail to my mailbox that names the failed jobs" do
    numbers = { signups_by_ref: { "peerlist" => 2 }, activated: 1, subscribes: 0, recap_intents: 0,
                weekly_mailed: 3, weekly_opened: 1, failed_jobs: 1, failed_job_classes: { "WeeklyEmailJob" => 1 } }

    mail = SystemMailer.owner_digest(numbers)

    expect(mail.to).to eq([ "tuxnotfound@cioga.eu" ])
    expect(mail.subject).to eq("Openstage week: 2 signups, 1 failed job")
    expect(mail.text_part.body.to_s).to include("peerlist: 2", "WeeklyEmailJob: 1", "https://openstage.dev/admin")
  end
end
