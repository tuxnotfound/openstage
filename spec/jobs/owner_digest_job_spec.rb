require "rails_helper"

RSpec.describe OwnerDigestJob, type: :job do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "mails the week's digest, even an empty week" do
    expect { described_class.perform_now }.to have_enqueued_mail(SystemMailer, :owner_digest)
  end
end
