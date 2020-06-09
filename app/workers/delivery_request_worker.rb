class DeliveryRequestWorker
  include Sidekiq::Worker

  sidekiq_options retry: 9

  sidekiq_retries_exhausted do |msg, _e|
    if msg["error_class"] == "RatelimitExceededError"
      email_id = msg["args"].first
      queue = msg["args"].second
      GovukStatsd.increment("delivery_request_worker.rescheduled")
      DeliveryRequestWorker.set(queue: queue).perform_in(30.seconds, email_id, queue)
    end
  end

  def perform(email_id, queue)
    time_monitor = TimeMonitor.new
    @email_id = email_id
    @queue = queue

    time_monitor.record("init")

    check_rate_limit!

    time_monitor.record("checked_rate_limit")

    email = MetricsService.delivery_request_worker_find_email do
      Email.find(email_id)
    end
    time_monitor.record("found_email")

    attempted = DeliveryRequestService.call(email: email, time_monitor: time_monitor)
    time_monitor.record("called_delivery_request_service")

    if attempted
      increment_rate_limiter
      time_monitor.record("incremented_rate_limiter")
    end

    logger.info(time_monitor.report)
  end

  def self.perform_async_in_queue(*args, queue:)
    set(queue: queue).perform_async(*args, queue)
  end

  def check_rate_limit!
    if rate_limit_exceeded?
      GovukStatsd.increment("delivery_request_worker.rate_limit_exceeded")
      raise RatelimitExceededError
    end
  end

  def rate_limit_exceeded?
    rate_limiter.exceeded?(
      "delivery_request",
      threshold: rate_limit_threshold,
      interval: rate_limit_interval,
    )
  end

  def increment_rate_limiter
    rate_limiter.add("delivery_request")
  end

  def rate_limit_threshold
    per_minute_to_allow_360_per_second = "21600"
    ENV.fetch("DELIVERY_REQUEST_THRESHOLD", per_minute_to_allow_360_per_second).to_i
  end

  def rate_limit_interval
    minute_in_seconds = "60"
    ENV.fetch("DELIVERY_REQUEST_INTERVAL", minute_in_seconds).to_i
  end

private

  attr_reader :email_id, :queue

  def rate_limiter
    Services.rate_limiter
  end

  class TimeMonitor
    def initialize
      @start_time = Time.zone.now
      @events = {}
    end

    def record(event)
      @events[event] = Time.zone.now
    end

    def report
      time_taken = Time.zone.now - start_time

      "Timing breakdown, total: #{format_time(time_taken)}\n#{events_breakdown}"
    end

  private

    attr_reader :events, :start_time

    def events_breakdown
      events.reduce("") do |memo, (name, time)|
        memo + "#{name}: #{format_time(time - start_time)}\n"
      end
    end

    def format_time(time_float)
      "#{time_float.round(4)}s"
    end
  end
end

class RatelimitExceededError < StandardError
end
