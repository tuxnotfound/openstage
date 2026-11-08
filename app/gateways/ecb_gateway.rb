# The European Central Bank's euro reference rates: public, no key, as XML.
class EcbGateway < ApplicationGateway
  # The last 90 days' rates, read as they are asked for, each as
  # { currency:, day:, per_euro: }, the currency as Stripe writes it.
  def self.recent_rates
    rates_in(get("/stats/eurofxref/eurofxref-hist-90d.xml"))
  end

  # Every rate since 1999, as recent_rates gives them.
  def self.all_rates
    rates_in(get("/stats/eurofxref/eurofxref-hist.xml"))
  end

  # Walks the XML and builds no tree of it: a tree of the whole history, over
  # 220,000 rates, takes about 260 MB of a 512 MB service.
  # A maintenance page answers 200 too: no rates is an error, never an empty
  # night that goes unnoticed.
  def self.rates_in(xml)
    Enumerator.new do |rates|
      day = nil
      any = false
      Nokogiri::XML::Reader(xml).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.local_name == "Cube"

        day = Date.parse(node.attribute("time")) if node.attribute("time")
        next unless node.attribute("currency")

        any = true
        rates << { currency: node.attribute("currency").downcase, day:, per_euro: node.attribute("rate").to_d }
      end
      raise Error, "The ECB sent no rates" unless any
    rescue Nokogiri::XML::SyntaxError => error
      raise Error, "The ECB sent broken XML: #{error.message}"
    end
  end

  def self.base_url
    "https://www.ecb.europa.eu"
  end
  private_class_method :rates_in, :base_url
end
