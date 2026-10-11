# The stop link in the builder's weekly email (F2). Settings turns it back on.
class WeeklyEmailsController < ApplicationController
  # The signed token is the credential; a mail client's one-click POST carries
  # no session and so no CSRF token.
  skip_forgery_protection only: :unsubscribe

  # GET for the link in the mail, POST for List-Unsubscribe-Post clients.
  def unsubscribe
    user = User.find_signed(params[:token].to_s, purpose: :weekly_email)
    return redirect_to(root_path, alert: "That link is no longer valid. Turn the email off in Settings.") unless user

    user.update!(weekly_email: false)
    redirect_to root_path, notice: "Done. No more weekly emails. Settings turns them back on."
  end
end
