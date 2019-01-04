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

  # def get_notify_email_status(id)
  #   puts "Notification details for email with id #{id}"
  #   notification = client.get_notification(id)
  #
  #   puts "Status: #{notification.status}"
  #   puts "Response: #{notification.response}"
  # end

  def get_notify_multiple_email_status(reference)
    #reference is the DeliveryAttempt.id
    puts "Query Notify for emails with the reference #{reference}"

    response = client.get_notifications(
      template_type: 'email',
      reference: reference
    )
    # puts "Response =  #{response}"
    if response.is_a?(Notifications::Client::NotificationsCollection)
      count = response.collection.count

      puts "Found #{count} notification(s)"

      response.collection.each do |notification|
        puts <<~TEXT
          -------------------------------------------
          Notification ID: #{notification.id}
          Status: #{notification.status}
          created_at: #{notification.created_at}
          sent_at: #{notification.sent_at}
          completed_at: #{notification.completed_at}
        TEXT

        # puts "==================================="
        # puts "Notification id: #{notification.id}"
        # puts "Status: #{notification.status}"
        # puts "created_at: #{notification.created_at}"
        # puts "sent_at: #{notification.sent_at}"
        # puts "completed_at: #{notification.completed_at}"
      end

    elsif response.is_a?(Notifications::Client::RequestError)
      puts "Query for #{reference} returns error code #{error.code}, #{error.message}"
    else
      puts "Reference not found"
    end
  end

private

  attr_reader :client, :template_id
end
