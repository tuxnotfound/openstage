# The app's look as mail clients draw it: inline styles only, and tables
# where Outlook needs them. Mail keeps to the app's light colours.
module MailHelper
  SANS = "'Funnel Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif".freeze
  DISPLAY = "'Funnel Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif".freeze
  FILL = "#F3F4F6".freeze
  ACCENT = "#006B72".freeze

  # A grey panel with soft corners, as .os-panel.
  def mail_panel(&block)
    tag.table(role: "presentation", width: "100%", cellpadding: 0, cellspacing: 0, border: 0, bgcolor: FILL,
              style: "border-collapse: separate; background: #{FILL}; border-radius: 22px; margin: 0 0 12px;") do
      tag.tr(tag.td(capture(&block), style: "padding: 24px;"))
    end
  end

  # A panel's heading, as .os-h3.
  def mail_heading(text)
    tag.p(text, style: "margin: 0 0 12px; font-family: #{DISPLAY}; font-size: 22px; font-weight: 700; letter-spacing: -0.02em; color: #0E0F12;")
  end

  # The app's main button, as .os-btn.
  def mail_button(label, url)
    link_to label, url, style: "display: inline-block; padding: 12px 20px; border-radius: 12px; background: #{ACCENT}; color: #FFFFFF; " \
                               "font-family: #{SANS}; font-size: 15px; font-weight: 700; text-decoration: none;"
  end
end
