# What a page on Openstage hands the browser to count its own view
# (PageViews::RecordService): whose page it is, which project's, and the site
# the visitor came from. Signed, so it cannot be made up, and dated, so it
# cannot be kept. The referrer is read as the server answers, because a Turbo
# visit never changes document.referrer.
module PageViewTicket
  PURPOSE = :page_view

  # The page sends it as it renders. One Turbo restores from its cache after
  # this is not a new view.
  LIFETIME = 10.minutes

  # repo_name: the project's, on a project's page; nil on the builder's stage.
  def self.issue(user:, referrer:, repo_name: nil)
    verifier.generate({ "u" => user.id, "r" => repo_name, "f" => referrer }.compact, purpose: PURPOSE, expires_in: LIFETIME)
  end

  # Its contents, or nil for a ticket Openstage did not issue or one that expired.
  def self.read(ticket)
    verifier.verified(ticket.to_s, purpose: PURPOSE)
  end

  def self.verifier
    Rails.application.message_verifier("page-views")
  end
end
