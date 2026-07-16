require 'open-uri'
require 'bigdecimal'

class ExchangeRateFetcherService
  def call(from = "USD", to = "RUB")
    data = URI.open("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml") { |f| f.read }
    document = Nokogiri::XML(data)
    from_rate =
      if from == "EUR"
        1
      else
        BigDecimal(document.css("Cube[currency=#{from}]").attribute("rate").value)
      end
    to_rate =
      if to == "EUR"
        1
      else
        BigDecimal(document.css("Cube[currency=#{to}]").attribute("rate").value)
      end
    to_rate / from_rate
  end
end
