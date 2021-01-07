class SendEmailService::SendNotifyEmail
  def initialize(email)
    @email = email
    @client = Notifications::Client.new(Rails.application.secrets.notify_api_key)
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    client.send_email(
      email_address: email.address,
      template_id: Rails.application.config.notify_template_id,
      reference: email.id,
      personalisation: {
        subject: email.subject,
        body: email.body,
      },
    )

    Metrics.sent_to_notify_successfully
    email.update!(status: :sent, sent_at: Time.zone.now)
  rescue Notifications::Client::RequestError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Metrics.failed_to_send_to_notify

    Rails.logger.warn(
      "Notify communication failure for reference #{email.id}. #{e.class}: #{e}",
    )

    if undeliverable_failure?(e)
      email.update!(status: :failed)
    else
      raise SendEmailService::NotifyCommunicationFailure
    end
  end

private

  attr_reader :email, :client

  def undeliverable_failure?(error)
    return false unless error.is_a?(Notifications::Client::BadRequestError)

    return true if error.message.end_with?("Not a valid email address")

    # This is a stop-gap fix for an issue where this system can produce emails
    # that are so long they exceed Notify's limit of 2MB. As emails of this
    # size will never succeed we mark them as failures. Ideally this will
    # eventually be resolved by some product thinking that only allows the
    # system to create emails within a reasonable length.
    error.message.start_with?("BadRequestError: Your message is too long")
  end
end
