# The European Central Bank's euro reference rates: public, no key, as XML.
class EcbGateway < ApplicationGateway
  # The last 90 days' rates, each as { currency:, day:, per_euro: }, the
  # currency as Stripe writes it.
  def self.recent_rates
    rates_in(get("/stats/eurofxref/eurofxref-hist-90d.xml"))
  end

  # Every rate since 1999, as recent_rates writes them.
  def self.all_rates
    rates_in(get("/stats/eurofxref/eurofxref-hist.xml"))
  end

  # A maintenance page answers 200 too: no rates is an error, never an empty
  # night that goes unnoticed.
  def self.rates_in(xml)
    rates = Nokogiri::XML(xml).remove_namespaces!.xpath("//Cube[@time]").flat_map do |day|
      day.xpath("Cube").map { |rate| { currency: rate["currency"].downcase, day: Date.parse(day["time"]), per_euro: rate["rate"].to_d } }
    end
    raise Error, "The ECB sent no rates" if rates.empty?

    rates
  end

  def self.base_url
    "https://www.ecb.europa.eu"
  end
  private_class_method :rates_in, :base_url
end
