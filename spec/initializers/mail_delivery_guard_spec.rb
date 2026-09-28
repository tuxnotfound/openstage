require "rails_helper"

RSpec.describe MailDeliveryGuard do
  let(:message) { Mail::Message.new(to: "reader@example.com", subject: "Confirm your subscription") }

  it "stays out of the way while deliveries are on" do
    expect { described_class.delivering_email(message) }.not_to raise_error
  end

  it "refuses to let a mail vanish, naming it" do
    allow(ActionMailer::Base).to receive(:perform_deliveries).and_return(false)

    expect { described_class.delivering_email(message) }
      .to raise_error(MailDeliveryGuard::Error, /Confirm your subscription.*reader@example\.com.*RESEND_API_KEY/m)
  end

  it "is registered, so no mailer can bypass it" do
    expect(Mail.class_variable_get(:@@delivery_interceptors)).to include(described_class)
  end

  it "fails the delivery job rather than reporting success" do
    user = create(:user, username: "builder")
    sub  = user.subscriptions.create!(email: "reader@example.com")
    allow(ActionMailer::Base).to receive(:perform_deliveries).and_return(false)

    expect {
      ActionMailer::MailDeliveryJob.perform_now("SubscriptionMailer", "confirm", "deliver_now", args: [ sub ])
    }.to raise_error(MailDeliveryGuard::Error)
  end
end
