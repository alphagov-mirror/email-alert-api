class ImmediateEmailBuilder
  def initialize(recipients_and_content)
    @recipients_and_content = recipients_and_content
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    Email.import!(columns, records)
  end

  private_class_method :new

private

  attr_reader :recipients_and_content

  def records
    recipients_and_content.map do |recipient_and_content|
      [
        recipient_and_content.fetch(:address),
        subject(recipient_and_content.fetch(:content_change)),
        body(recipient_and_content.fetch(:content_change), recipient_and_content.fetch(:subscriptions))
      ]
    end
  end

  def columns
    %i(address subject body)
  end

  def subject(content_change)
    "GOV.UK update - #{content_change.title}"
  end

  def body(content_change, subscriptions)
    if Array(subscriptions).empty?
      presented_content_change(content_change)
    else
      <<~BODY
        #{presented_content_change(content_change)}
        ---

        #{presented_unsubscribe_links(subscriptions)}
      BODY
    end
  end

  def presented_content_change(content_change)
    ContentChangePresenter.call(content_change)
  end

  def presented_unsubscribe_links(subscriptions)
    links_array = subscriptions.map do |subscription|
      UnsubscribeLinkPresenter.call(
        id: subscription.id,
        title: subscription.subscriber_list.title,
      )
    end

    links_array.join("\n")
  end
end
