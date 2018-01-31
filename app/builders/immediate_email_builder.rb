class ImmediateEmailBuilder
  def initialize(subscription_content_changes)
    @subscription_content_changes = subscription_content_changes
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    Email.import!(columns, records)
  end

  private_class_method :new

private

  attr_reader :subscription_content_changes

  def records
    subscription_content_changes.map do |subscription_content_change|
      single_email_record(subscription_content_change)
    end
  end

  def columns
    %i(address subject body)
  end

  def single_email_record(subscription_content_change)
    content_change = subscription_content_change.fetch(:content_change)
    subscription = subscription_content_change[:subscription]

    subscriber = if subscription
                   subscription.subscriber
                 else
                   subscription_content_change.fetch(:subscriber)
                 end

    [subscriber.address, subject(content_change), body(subscriber, content_change)]
  end

  def subject(content_change)
    "GOV.UK Update - #{content_change.title}"
  end

  def body(subscriber, content_change)
    <<~BODY
      #{presented_content_change(content_change)}
      ---

      #{unsubscribe_links(subscriber)}
    BODY
  end

  def presented_content_change(content_change)
    ContentChangePresenter.call(content_change)
  end

  def unsubscribe_links(subscriber)
    links = subscriber.subscriptions.map do |subscription|
      UnsubscribeLinkPresenter.call(uuid: subscription.uuid, title: subscription.subscriber_list.title)
    end

    links.join("\n\n")
  end
end
