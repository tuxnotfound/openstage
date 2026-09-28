require "rails_helper"

RSpec.describe MailDeliveryGuard do
  let(:message) { Mail::Message.new(to: "reader@example.com", subject: "Confirm your subscription") }

  it "stays quiet while deliveries are on" do
    expect(Rails.logger).not_to receive(:warn)
    described_class.delivering_email(message)
  end

  it "names the mail it is about to drop" do
    allow(ActionMailer::Base).to receive(:perform_deliveries).and_return(false)

    expect(Rails.logger).to receive(:warn).with(/DROPPED.*Confirm your subscription.*reader@example\.com/)
    described_class.delivering_email(message)
  end

  it "is registered, so a dropped mail cannot pass unnoticed" do
    expect(Mail.class_variable_get(:@@delivery_interceptors)).to include(described_class)
  end
end
