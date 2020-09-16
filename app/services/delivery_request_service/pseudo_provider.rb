class DeliveryRequestService::PseudoProvider
  LOG_PATH = Rails.root.join("log/pseudo_email.log").freeze

  def self.call(*args)
    new.call(*args)
  end

  def call(address:, subject:, body:, reference:)
    logger.info(<<-INFO.strip_heredoc)
      Sending email to #{address}
      Subject: #{subject}
      Body: #{body}
      Reference: #{reference}
    INFO

    Metrics.sent_to_pseudo_successfully
    :delivered
  end

  private_class_method :new

private

  def logger
    @logger ||= Logger.new(LOG_PATH, 5, 4_194_304)
  end
end
