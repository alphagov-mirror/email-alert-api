class DeliveryRequestService
  PROVIDERS = {
    "notify" => NotifyProvider,
    "pseudo" => PseudoProvider,
    "delay" => DelayProvider,
  }.freeze

  attr_reader :provider_name, :provider, :subject_prefix, :overrider

  def initialize(config: EmailAlertAPI.config.email_service)
    @provider_name = config.fetch(:provider).downcase
    @provider = PROVIDERS.fetch(provider_name)
    @subject_prefix = config.fetch(:email_subject_prefix)
    @overrider = EmailAddressOverrider.new(config)
  end

  def self.call(*args)
    new.call(*args)
  end

  def call(email:, time_monitor: nil)
    reference = SecureRandom.uuid

    address = determine_address(email, reference)
    time_monitor&.record("determine_address")
    return false if address.nil?

    delivery_attempt = create_delivery_attempt(email, reference, time_monitor)

    status = MetricsService.email_send_request(provider_name) do
      call_provider(address, reference, email)
    end

    time_monitor&.record("called_provider")

    return true if status == :sending

    ActiveRecord::Base.transaction do
      delivery_attempt.update!(status: status, completed_at: Time.zone.now)
      time_monitor&.record("updated_delivery_attempt")
      MetricsService.delivery_attempt_status_changed(status)
      UpdateEmailStatusService.call(delivery_attempt)
      time_monitor&.record("updated_email_status")
    end

    true
  end

private

  def call_provider(address, reference, email)
    provider.call(
      address: address,
      subject: subject_prefix + email.subject,
      body: email.body,
      reference: reference,
    )
  rescue StandardError => e
    GovukError.notify(e)
    :internal_failure
  end

  def determine_address(email, reference)
    overrider.destination_address(email.address).tap do |address|
      next if address == email.address

      Rails.logger.info(<<-INFO.strip_heredoc)
        Overriding email address #{email.address} to #{address}
        For email with reference: #{reference}
      INFO
    end
  end

  def create_delivery_attempt(email, reference, time_monitor)
    MetricsService.delivery_request_service_first_delivery_attempt do
      delivery_attempt_exists = DeliveryAttempt.exists?(email: email)
      time_monitor&.record("check_delivery_attempt_exists")
      record_first_attempt_metrics(email, time_monitor) unless delivery_attempt_exists
    end
    time_monitor&.record("record_first_delivery_attempt")

    MetricsService.delivery_request_service_create_delivery_attempt do
      DeliveryAttempt.create!(
        id: reference,
        email: email,
        status: :sending,
        provider: provider_name,
      ).tap do
        time_monitor&.record("created_delivery_attempt")
      end
    end
  end

  def record_first_attempt_metrics(email, time_monitor)
    now = Time.now.utc
    MetricsService.email_created_to_first_delivery_attempt(email.created_at, now)

    content_change_id = SubscriptionContent.where(email: email)
                                           .immediate
                                           .pick(:content_change_id)
    time_monitor&.record("find_content_change_id")
    return unless content_change_id

    content_change_created_at = ContentChange.where(id: content_change_id)
                                             .pick(:created_at)
    time_monitor&.record("check_content_change_created_at")
    return unless content_change_created_at

    MetricsService.content_change_created_to_first_delivery_attempt(content_change_created_at, now)
  end

  class EmailAddressOverrider
    attr_reader :override_address, :whitelist_addresses, :whitelist_only

    def initialize(config)
      @override_address = config[:email_address_override]
      @whitelist_addresses = Array(config[:email_address_override_whitelist])
      @whitelist_only = config[:email_address_override_whitelist_only]
    end

    def destination_address(address)
      return address unless override_address

      if whitelist_addresses.include?(address)
        address
      else
        whitelist_only ? nil : override_address
      end
    end
  end
end
