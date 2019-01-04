class NotifyProvider
  def initialize(config: EmailAlertAPI.config.notify)
    api_key = config.fetch(:api_key)
    base_url = config.fetch(:base_url)

    @client = Notifications::Client.new(api_key, base_url)
    @template_id = config.fetch(:template_id)
  end

  def self.call(*args)
    new.call(*args)
  end

  def call(address:, subject:, body:, reference:)
    client.send_email(
      email_address: address,
      template_id: template_id,
      reference: reference,
      personalisation: {
        subject: subject,
        body: body,
      },
    )

    MetricsService.sent_to_notify_successfully
    :sending
  rescue StandardError => e
    MetricsService.failed_to_send_to_notify
    GovukError.notify(e, tags: { provider: "notify" })
    :technical_failure
  end

  def get_notify_email_status(id)
    puts "Notification details for email with id #{id}"
    notification = client.get_notification(id)

    puts "Status: #{notification.status}"
    puts "Response: #{notification.response}"
  end

  def get_notify_multiple_email_status(reference)
    #reference is the DeliveryAttempt.id
    puts "Query Notify for emails with the reference #{reference}"

    response = client.get_notifications(
      template_type: 'email',
      reference: reference
    )

    puts "Response =  #{response}"

    count = response.collection.count

    puts "Found #{count} results"
  end

private

  attr_reader :client, :template_id
end
