module ShareCards
  # What the card a shared link shows draws for a builder's page, or for one of
  # their projects: the page's own cards (Progress::GatherService, or
  # FocusService for a project) and the builder's avatar, which the card
  # carries inline.
  class GatherService < ApplicationService
    AVATAR_SIZE = 192

    # slug: a project's name, as in its page's URL; none for the builder's card.
    attr_accessor :user, :slug
    # cards: the builder's, in the page's order, or the project's alone.
    # avatar: image bytes; nil when GitHub gives none, and the card shows initials.
    attr_reader :cards, :avatar

    validates :user, presence: true

    private

    def execute
      page = slug ? Progress::FocusService.new(user: user, slug: slug) : Progress::GatherService.new(user: user)
      page.call
      return unless absorb_errors(page)

      @cards = slug ? [ page.card ] : page.cards
      @avatar = fetch_avatar
    end

    # Kept a day. A card is still worth drawing without the avatar, so a
    # failed fetch is reported and the card goes on with initials.
    def fetch_avatar
      Rails.cache.fetch([ "avatar", user.avatar_url, AVATAR_SIZE ], expires_in: 1.day) do
        AvatarGateway.image(user.avatar_url, size: AVATAR_SIZE)
      end
    rescue ApplicationGateway::Error => error
      Rails.error.report(error, handled: true)
      nil
    end
  end
end
