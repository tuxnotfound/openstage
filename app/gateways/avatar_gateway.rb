# A builder's GitHub avatar as image bytes, for the share cards: librsvg draws
# no image from the network, so the card carries it inline.
class AvatarGateway < ApplicationGateway
  HOST = "avatars.githubusercontent.com".freeze

  # The avatar at `size` pixels square; nil for an address GitHub does not serve.
  def self.image(url, size:)
    uri = URI.parse(url.to_s)
    return unless uri.scheme == "https" && uri.host == HOST

    get(uri.path, query: URI.decode_www_form(uri.query.to_s).to_h.merge("s" => size.to_s), headers: { "Accept" => "image/*" })
  rescue URI::InvalidURIError
    nil
  end

  def self.base_url
    "https://#{HOST}"
  end
  private_class_method :base_url
end
