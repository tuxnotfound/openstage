# Owner-only smoke test, so "does production actually send?" is answerable
# without a console. This is F1's verification step, available early.
class SystemMailer < ApplicationMailer
  def test_email(user)
    @user = user
    @sent_at = Time.current

    mail(to: user.email, subject: "Openstage production email works")
  end

  # F4. Goes to the Reply-To mailbox, the one address known to reach me.
  def owner_digest(numbers)
    @numbers = numbers
    @signups = numbers[:signups_by_ref].values.sum
    @admin_url = admin_url

    mail(to: self.class.default_params[:reply_to],
         subject: "Openstage week: #{@signups} #{'signup'.pluralize(@signups)}, #{numbers[:failed_jobs]} failed #{'job'.pluralize(numbers[:failed_jobs])}")
  end
end
