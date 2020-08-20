class DigestItemsQuery
  Result = Struct.new(:subscription_id, :subscriber_list_title, :subscriber_list_url, :subscriber_list_description, :content)

  def initialize(subscriber, digest_run)
    @subscriber = subscriber
    @digest_run = digest_run
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    build_results(fetch_content_changes, fetch_messages)
  end

  private_class_method :new

private

  attr_reader :subscriber, :digest_run

  def build_results(content_changes, messages)
    result_data = content_changes.each_with_object({}) do |record, memo|
      id = record[:subscription_id]
      memo[id] ||= {
        subscriber_list_title: record[:subscriber_list_title],
        subscriber_list_url: record[:subscriber_list_url],
        subscriber_list_description: record[:subscriber_list_description],
      }
      memo[id][:content_changes] = Array(memo[id][:content_changes]) << record
    end

    result_data = messages.each_with_object(result_data) do |record, memo|
      id = record[:subscription_id]
      memo[id] ||= {
        subscriber_list_title: record[:subscriber_list_title],
        subscriber_list_url: record[:subscriber_list_url],
        subscriber_list_description: record[:subscriber_list_description],
      }
      memo[id][:messages] = Array(memo[id][:messages]) << record
    end

    result_data.map do |key, value|
      content = value.fetch(:content_changes, []) + value.fetch(:messages, [])
      Result.new(key, value[:subscriber_list_title], value[:subscriber_list_url], value[:subscriber_list_description], content.sort_by(&:created_at))
    end
  end

  def fetch_content_changes
    ContentChange
      .select("content_changes.*", "subscriptions.id AS subscription_id", "subscriber_lists.title AS subscriber_list_title", "subscriber_lists.url AS subscriber_list_url", "subscriber_lists.description AS subscriber_list_description")
      .joins(matched_content_changes: { subscriber_list: { subscriptions: :subscriber } })
      .where(subscribers: { id: subscriber.id })
      .where(subscriptions: { frequency: Subscription.frequencies[digest_run.range] })
      .where("content_changes.created_at >= ?", digest_run.starts_at)
      .where("content_changes.created_at < ?", digest_run.ends_at)
      .merge(Subscription.active)
      .order("subscriber_list_title ASC", "subscriber_list_url ASC", "subscriber_list_description ASC", "content_changes.created_at ASC")
      .uniq(&:content_id)
  end

  def fetch_messages
    Message
      .select("messages.*", "subscriptions.id AS subscription_id", "subscriber_lists.title AS subscriber_list_title", "subscriber_lists.url AS subscriber_list_url", "subscriber_lists.description AS subscriber_list_description")
      .joins(matched_messages: { subscriber_list: { subscriptions: :subscriber } })
      .where(subscribers: { id: subscriber.id })
      .where(subscriptions: { frequency: Subscription.frequencies[digest_run.range] })
      .where("messages.created_at >= ?", digest_run.starts_at)
      .where("messages.created_at < ?", digest_run.ends_at)
      .merge(Subscription.active)
      .order("subscriber_list_title ASC", "subscriber_list_url ASC", "subscriber_list_description ASC", "messages.created_at ASC")
      .uniq(&:id)
  end
end
