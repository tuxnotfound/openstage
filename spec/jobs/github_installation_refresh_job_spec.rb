require "rails_helper"

RSpec.describe GithubInstallationRefreshJob, type: :job do
  let(:user) { create(:user) }

  it "refreshes the builder's installation" do
    refresh = instance_double(GithubInstallations::RefreshService, call!: true)
    allow(GithubInstallations::RefreshService).to receive(:new).with(user: user).and_return(refresh)

    described_class.new.perform(user.id)

    expect(refresh).to have_received(:call!)
  end

  it "skips a deleted account" do
    user.soft_delete!
    allow(GithubInstallations::RefreshService).to receive(:new)

    described_class.new.perform(user.id)

    expect(GithubInstallations::RefreshService).not_to have_received(:new)
  end

  # GitHub never redelivers a webhook, so the job retries a passing GitHub error.
  describe "when GitHub has a passing error" do
    around do |example|
      adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = adapter
    end

    [
      ApplicationGateway::ServerError.new(status: 502),
      ApplicationGateway::ConnectionFailed.new("timeout"),
      ApplicationGateway::RateLimited.new(status: 429)
    ].each do |error|
      it "retries after #{error.class.name.demodulize}" do
        allow(GithubInstallations::RefreshService).to receive(:new).and_raise(error)

        expect { described_class.perform_now(user.id) }.to have_enqueued_job(described_class).with(user.id)
      end
    end

    it "does not retry a wrong configuration" do
      allow(GithubInstallations::RefreshService).to receive(:new).and_raise(GithubAppGateway::Misconfigured.new("bad key"))

      expect { described_class.perform_now(user.id) }.to raise_error(GithubAppGateway::Misconfigured)
    end
  end
end
