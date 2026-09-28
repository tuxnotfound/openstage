xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "#{@user.display_name} on Openstage"
    xml.description(@user.bio.presence || "#{@user.display_name}'s proof-of-work page.")
    xml.link profile_url(@user.username)
    xml.tag! "atom:link", href: profile_url(@user.username, format: :rss), rel: "self", type: "application/rss+xml"
    xml.language "en"

    @rss_entries.each do |entry|
      xml.item do
        xml.title entry.title
        xml.description entry.body.presence || entry.title
        xml.link(safe_external_url(entry.url) || profile_url(@user.username, anchor: "entry-#{entry.id}"))
        xml.guid profile_url(@user.username, anchor: "entry-#{entry.id}"), isPermaLink: false
        xml.pubDate entry.occurred_at.rfc2822
        xml.category entry.repo_name if entry.repo_name.present?
      end
    end
  end
end
