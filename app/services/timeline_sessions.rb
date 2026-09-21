# Turns a page of timeline entries into what a visitor should read: a run of
# commits to one repo on one day becomes a single "work session", everything
# else stays as it is. Presentation only. No row is changed, so it applies to
# history and can be removed without a trace.
#
# It never ranks. Every commit in a session is still listed, in order.
class TimelineSessions
  MIN_SIZE = 3
  PREVIEW  = 3

  Session = Struct.new(:entries, keyword_init: true) do
    def repo_name   = entries.first.repo_name
    def occurred_at = entries.first.occurred_at
    def size        = entries.size
    def preview     = entries.first(PREVIEW)
    def rest        = entries.drop(PREVIEW)
    def dom_id      = "session-#{entries.first.id}"
  end

  def self.group(entries)
    entries.to_a.chunk_while { |a, b| same_session?(a, b) }.flat_map do |run|
      run.size >= MIN_SIZE && groupable?(run.first) ? [ Session.new(entries: run) ] : run
    end
  end

  def self.groupable?(entry)
    entry.source == "github" && entry.entry_type == "shipped" && entry.repo_name.present? && !entry.pinned?
  end

  def self.same_session?(a, b)
    groupable?(a) && groupable?(b) &&
      a.repo_name == b.repo_name &&
      a.occurred_at.utc.to_date == b.occurred_at.utc.to_date
  end
end
