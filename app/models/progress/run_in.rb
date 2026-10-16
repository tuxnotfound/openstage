module Progress
  # A title that ends in ":" continues into its own body, in muted ink:
  # "This week's build log: Trained on me is live!! · UI cleanup · …". Bullet
  # markers go, and so do empty lines and lines that repeat the title or name
  # a project.
  module RunIn
    # The page caps a run-in at this many characters, on a word.
    PAGE_LIMIT = 160

    module_function

    def of(title, body, project_names)
      title = title.to_s.strip
      return "" unless title.end_with?(":") && body.present?

      body.lines.map { |line| line.sub(/\A\s*[-*•]\s*/, "").strip }
          .reject { |line| line.empty? || line == title || project_names.include?(line) }.join(" · ")
    end

    def capped(text, limit = PAGE_LIMIT)
      chars = text.grapheme_clusters
      return text if chars.size <= limit

      cut = chars.first(limit + 1).join
      space = cut.rindex(" ")
      kept = space&.positive? ? cut[0...space] : chars.first(limit).join
      "#{kept.sub(/[\s,;:·–—-]+\z/, '')}…"
    end
  end
end
