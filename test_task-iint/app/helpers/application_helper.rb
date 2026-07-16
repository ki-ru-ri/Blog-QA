module ApplicationHelper
  def usd_to_czk(value)
    @rate ||= ExchangeRateFetcherService.new.call("USD", "CZK")
    @rate * value
  end
end
