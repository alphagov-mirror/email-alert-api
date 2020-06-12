class ImmediateEmailGenerationService
  class Batch
    def initialize(content, subscription_ids_by_subscriber)
      @content = content
      @subscription_ids_by_subscriber = subscription_ids_by_subscriber
    end

    def generate_emails
      email_ids = []
      return email_ids unless email_parameters.any?

      ActiveRecord::Base.transaction do
        email_ids = ContentChangeEmailBuilder.call(email_parameters).ids if content_change
        email_ids = MessageEmailBuilder.call(email_parameters).ids if message

        records = subscription_content_records(email_ids)
        SubscriptionContent.populate_for_content(content, records)
      end

      email_ids
    end

  private

    attr_reader :subscription_ids_by_subscriber, :content

    def email_parameters
      @email_parameters ||= begin
        subscription_ids_by_subscriber
          .each_with_object([]) do |(subscriber_id, subscription_ids), memo|
            subscriber = subscribers[subscriber_id]
            subscriptions = subscription_ids.map { |id| active_subscriptions[id] }
                                            .compact
            next if !subscriber || subscriptions.empty?

            memo << {
              address: subscriber.address,
              content_change: content_change,
              message: message,
              subscriptions: subscriptions,
              subscriber_id: subscriber.id,
            }.compact
          end
      end
    end

    def subscription_content_records(email_ids)
      email_parameters.flat_map.with_index do |params, index|
        params[:subscriptions].map do |subscription|
          { subscription_id: subscription.id, email_id: email_ids[index] }
        end
      end
    end

    def subscribers
      @subscribers ||= Subscriber.activated
                                 .where(id: subscription_ids_by_subscriber.keys)
                                 .index_by(&:id)
    end

    def active_subscriptions
      @active_subscriptions ||= Subscription.active
                                            .immediately
                                            .includes(:subscriber_list)
                                            .where(id: unfulfilled_subscription_ids)
                                            .index_by(&:id)
    end

    def unfulfilled_subscription_ids
      candidates = subscription_ids_by_subscriber.values.flatten
      criteria = { message: message,
                   content_change: content_change,
                   subscription_id: candidates }.compact

      already_fulfilled = SubscriptionContent.where(criteria)
                                             .pluck(:subscription_id)

      subscription_ids_by_subscriber.values.flatten - already_fulfilled
    end

    def content_change
      content if content.is_a?(ContentChange)
    end

    def message
      content if content.is_a?(Message)
    end
  end
end
