# Owner-only smoke test, so "does production actually send?" is answerable
# without a console. This is F1's verification step, available early.
class SystemMailer < ApplicationMailer
  def test_email(user)
    @user = user
    @sent_at = Time.current

    mail(to: user.email, subject: "Openstage production email works")
  end
end
