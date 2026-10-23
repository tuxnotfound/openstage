# F2's two emails. Both show the Week view of the builder's progress section
# as it stands when they are sent, from public entries only, so nothing
# private reaches a subscriber and the page they link to says the same.
class WeeklyMailer < ApplicationMailer
  helper :progress

  # The builder's own week, and one link: their page. It never posts.
  def week_ready(user)
    @section    = week_of(user)
    attach_chart(@section)
    @page_url   = profile_url(user.username, range: "30d", ref: "weekly")
    @log_url    = dashboard_url
    @stop_url   = weekly_email_unsubscribe_url(token: user.signed_id(purpose: :weekly_email))
    one_click_unsubscribe(@stop_url)

    mail(to: user.email, subject: "Your week on Openstage")
  end

  # The week a subscriber asked for when they confirmed: the builder's whole
  # page, or one project's.
  def digest(subscription)
    @builder     = subscription.user
    @project     = subscription.github_repo
    @section     = week_of(@builder, @project)
    attach_chart(@section)
    @page_url    = digest_page_url
    @home_url    = root_url(ref: "digest")
    @unsub_url   = unsubscribe_subscription_url(subscription.token)
    one_click_unsubscribe(@unsub_url)

    subject = @project ? "#{@project.name} this week, by #{@builder.display_name}" : "#{@builder.display_name}'s week on Openstage"
    mail(to: subscription.email, subject: subject)
  end

  private

  def week_of(user, project = nil)
    Progress::ComposeService.new(user: user, range: "week", repos: Array(project&.full_name)).tap(&:call!).section
  end

  def digest_page_url
    return profile_url(@builder.username, range: "30d", ref: "digest") unless @project

    project_page_url(@builder.username, @project.name, range: "30d", ref: "digest")
  end

  # The page's chart, as a picture the email carries; none for a week with no
  # commits, which the email says in words instead.
  def attach_chart(section)
    chart = ProgressChart::Trend.new(section, discs: true)
    attachments.inline[ProgressChart::EmailImage::FILE] = ProgressChart::EmailImage.new(chart).png if chart.lines.any?
  end

  def one_click_unsubscribe(url)
    headers["List-Unsubscribe"] = "<#{url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end
end
