# A page whose views count, a builder's stage or a project's page, hands the
# browser a ticket (PageViewTicket) to send back once the page runs there
# (page_view_controller.js). The view counts then, not as the server answers,
# so a client that only fetches the page counts none.
module CountsPageViews
  extend ActiveSupport::Concern

  private

  # Nil for the builder's own visit and for a bot's: neither counts.
  def view_ticket(user, repo_name: nil)
    return if current_user == user || BotDetector.bot?(request.user_agent)

    PageViewTicket.issue(user: user, repo_name: repo_name, referrer: referrer_host)
  end

  def referrer_host
    URI.parse(request.referer).host if request.referer.present?
  rescue URI::InvalidURIError
    nil
  end
end
