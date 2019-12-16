module OverallMetricsService
  def self.statsd
    @statsd ||= begin
      statsd = Statsd.new
      statsd.namespace = "govuk.email-alert-api"
      statsd
    end
  end

  def self.gauge(stat, metric)
    statsd.gauge(stat, metric)
  end
end
