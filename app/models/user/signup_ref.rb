class User
  # Where a signup came from, captured once at first touch. Anything else is
  # recorded as "direct" so the denominator is never silently incomplete.
  # "bio" is the link in the founder's X profile, so reply-first presence on X
  # is attributed separately from recap posts.
  # "launch" is the tag on the links in the soft-launch posts. A launch venue
  # with a gate read of its own gets its own tag: "peerlist" (the Gate 1
  # retry) and "producthunt" (the card). The free boards listed in the
  # Product Hunt week get one each, so a listing's signups never land as
  # "direct". "digest" is the subscriber digest. "reddit" is every link
  # posted on Reddit. "x" is every link posted on X but the bio's.
  # "buildinpublic" is the listing on buildinpublic.com, whose links carry it
  # as ?via= rather than ?ref=. "github" is every link in Openstage's own
  # repository on GitHub (its README). "project" is the button at the foot
  # of a builder's project page.
  module SignupRef
    extend ActiveSupport::Concern

    REFS = %w[recap badge footer feed claim bio launch peerlist producthunt
              devhunt saashub alternativeto digest reddit x buildinpublic github
              project].freeze
    DEFAULT_REF = "direct".freeze

    class_methods do
      def normalize_ref(value)
        ref = value.to_s.downcase.strip
        REFS.include?(ref) ? ref : DEFAULT_REF
      end
    end
  end
end
