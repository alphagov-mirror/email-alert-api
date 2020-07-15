class MetricsService
  class << self
    def content_change_emails(content_change, count)
      count("content_change_emails.publishing_app.#{content_change.publishing_app}.immediate", count)
      count("content_change_emails.document_type.#{content_change.document_type}.immediate", count)
    end

    def sent_to_notify_successfully
      increment("notify.email_send_request.success")
    end

    def failed_to_send_to_notify
      increment("notify.email_send_request.failure")
    end

    def sent_to_pseudo_successfully
      increment("pseudo.email_send_request")
    end

    def content_change_created
      increment("content_changes_created")
    end

    def message_created
      increment("messages_created")
    end

    def email_send_request(provider_name, &block)
      time("#{provider_name}.email_send_request.timing", &block)
    end

    def digest_email_generation(range, &block)
      time("digest_email_generation.#{range}.timing", &block)
    end

    def digest_initiator_service(range, &block)
      time("digest_initiator_service.#{range}.timing", &block)
    end

    def email_bulk_insert(size, &block)
      time("email_bulk_insert.#{size}.timing", &block)
    end

    def delivery_request_worker_find_email(&block)
      time("delivery_request_worker_find_email.timing", &block)
    end

    def delivery_request_service_first_delivery_attempt(&block)
      time("delivery_request_service_first_delivery_attempt.timing", &block)
    end

    def delivery_request_service_create_delivery_attempt(&block)
      time("delivery_request_service_create_delivery_attempt.timing", &block)
    end

    def email_created_to_first_delivery_attempt(created_time, first_attempt_time)
      difference = (first_attempt_time - created_time) * 1000
      timing("email_created_to_first_delivery_attempt", difference)
    end

    def content_change_created_to_first_delivery_attempt(created_time, first_attempt_time)
      difference = (first_attempt_time - created_time) * 1000
      timing("content_change_created_to_first_delivery_attempt", difference)
    end

    def delivery_attempt_status_changed(status)
      increment("delivery_attempt.status.#{status}")
    end

  private

    def increment(metric)
      GovukStatsd.increment(metric)
    end

    def time(metric, &block)
      GovukStatsd.time(metric, &block)
    end

    def timing(namespace, difference)
      GovukStatsd.timing(namespace, difference)
    end

    def count(namespace, value)
      GovukStatsd.count(namespace, value)
    end
  end
end
