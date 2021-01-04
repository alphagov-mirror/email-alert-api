class BulkSubscriberListEmailBuilder < ApplicationBuilder
  BATCH_SIZE = 5000

  def initialize(subject:, body:, subscriber_lists:)
    @subject = subject
    @body = body
    @subscriber_lists = subscriber_lists
    @now = Time.zone.now
  end

  def call
    batches.flat_map do |batch|
      records = records_for_batch(batch.to_h)
      Email.insert_all!(records).pluck("id")
    end
  end

private

  attr_reader :subject, :body, :subscriber_lists, :now

  def records_for_batch(batch)
    subscribers = Subscriber.find(batch.keys).index_by(&:id)
    subscriptions = Subscription.find(batch.values).index_by(&:id)

    batch.map do |subscriber_id, subscription_ids|
      subscriber = subscribers[subscriber_id]

      subscription = subscriptions.slice(*subscription_ids)
        .values.max_by(&:created_at)

      {
        address: subscriber.address,
        subject: subject,
        body: body + footer(subscriber, subscription),
        subscriber_id: subscriber_id,
        created_at: now,
        updated_at: now,
      }
    end
  end

  def footer(subscriber, subscription)
    list = subscription.subscriber_list

    unsubscribe_url = PublicUrls.unsubscribe(
      subscription_id: subscription.id,
      subscriber_id: subscriber.id,
    )

    manage_url = PublicUrls.authenticate_url(
      address: subscriber.address,
    )

    "\n\n" + <<~FOOTER
      ---

      # Why am I getting this email?

      You asked GOV.UK to send you an email each time we add or update a page about:

      #{list.title}

      [Unsubscribe](#{unsubscribe_url})

      [Manage your email preferences](#{manage_url})
    FOOTER
  end

  def batches
    Subscription
      .active
      .where(subscriber_list: subscriber_lists)
      .subscription_ids_by_subscriber
      .each_slice(BATCH_SIZE)
  end
end
