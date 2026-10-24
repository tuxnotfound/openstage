module ApplicationHelper
  # Never emit a user-supplied URL into an href without checking the scheme.
  # The model validates new input; this covers rows written before it existed.
  def safe_external_url(value)
    uri = URI.parse(value.to_s)
    value if %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    nil
  end

  # Builds the X share intent locally. This replaced a tinyurl_for helper that
  # called tinyurl.com from inside the dashboard's entry loop: its cache key was
  # "tinyurl_v2:#{url.hash}", and Ruby seeds String#hash per process, so the key
  # never repeated and the cache never hit. Every dashboard render made one
  # 3-second-timeout HTTP call per entry. Shortening bought nothing anyway,
  # since X wraps every link in t.co regardless.
  def share_on_x_url(entry, user)
    parts = [ entry.title ]
    parts << entry.body.truncate(100) if entry.body.present?
    parts << public_entry_url(entry, user)

    "https://twitter.com/intent/tweet?text=#{CGI.escape(parts.join("\n\n"))}"
  end

  # An entry on the builder's public page. ?entry= makes the page show it
  # wherever it falls; the anchor scrolls to it.
  def public_entry_url(entry, user)
    profile_url(user.username, entry: entry.id, anchor: "entry-#{entry.id}")
  end

  # The tab each controller's pages sit under in the app header. A page reached
  # from inside a tab (an entry's edit form, the week card) keeps that tab lit.
  NAV_TABS = {
    "dashboard" => :dashboard, "entries" => :dashboard,
    "analytics" => :analytics,
    "settings" => :settings, "github_repos" => :settings
  }.freeze

  # A tab in the app header, marked when the page being shown sits under it.
  def nav_link(label, path, tab)
    link_to label, path, aria: { current: (current_nav_tab == tab ? "page" : nil) }
  end

  # The builder's own profile is their page; someone else's sits under no tab.
  def current_nav_tab
    return :page if controller_name == "profiles" && current_page?(profile_path(current_user.username))

    NAV_TABS[controller_name]
  end

  # A React island over the HTML the server renders for it, which shows until
  # the script mounts and to any visitor without it. The props go in the JSON
  # beside it (app/javascript/charts/index.tsx).
  def react_island(name, props, id:, **options, &block)
    safe_join([
      tag.div(**options, data: { react: name, react_props: "#{id}-props" }, &block),
      tag.script(json_escape(props.to_json).html_safe, type: "application/json", id: "#{id}-props")
    ])
  end

  # The body's data-theme: the visitor's pick, or the system's until they
  # pick (nil).
  def color_theme
    cookies[:theme].presence_in(%w[light dark])
  end

  def streak_emoji(streak)
    case streak
    when 1    then "🐢"
    when 2..3 then "🌱"
    when 4..9 then "⚡"
    else
      fires = [streak / 10, 3].min
      streak >= 30 ? "🔥" * 3 + "🚀" : "🔥" * fires
    end
  end
end
