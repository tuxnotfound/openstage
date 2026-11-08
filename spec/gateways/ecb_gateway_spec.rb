require "rails_helper"

RSpec.describe EcbGateway do
  let(:xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
        <gesmes:subject>Reference rates</gesmes:subject>
        <Cube>
          <Cube time="2026-11-06"><Cube currency="USD" rate="1.0842"/><Cube currency="JPY" rate="162.12"/></Cube>
          <Cube time="2026-11-05"><Cube currency="USD" rate="1.0801"/></Cube>
        </Cube>
      </gesmes:Envelope>
    XML
  end

  it "reads the last 90 days' rates per euro, each currency as Stripe writes it" do
    stub_request(:get, "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml").to_return(status: 200, headers: { "Content-Type" => "text/xml" }, body: xml)

    expect(described_class.recent_rates).to eq([ { currency: "usd", day: Date.new(2026, 11, 6), per_euro: "1.0842".to_d },
                                                 { currency: "jpy", day: Date.new(2026, 11, 6), per_euro: "162.12".to_d },
                                                 { currency: "usd", day: Date.new(2026, 11, 5), per_euro: "1.0801".to_d } ])
  end

  it "reads every rate from the whole history" do
    stub = stub_request(:get, "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.xml").to_return(status: 200, headers: { "Content-Type" => "text/xml" }, body: xml)

    expect(described_class.all_rates.size).to eq(3)
    expect(stub).to have_been_requested
  end

  it "raises on a page with no rates, so a night without them shows as a failed job" do
    stub_request(:get, %r{/eurofxref-hist-90d.xml}).to_return(status: 200, headers: { "Content-Type" => "text/html" }, body: "<html>Down for maintenance</html>")

    expect { described_class.recent_rates }.to raise_error(ApplicationGateway::Error, "The ECB sent no rates")
  end

  it "raises the gateway's error on an outage" do
    stub_request(:get, %r{/eurofxref-hist-90d.xml}).to_return(status: 503)

    expect { described_class.recent_rates }.to raise_error(ApplicationGateway::ServerError)
  end
end
