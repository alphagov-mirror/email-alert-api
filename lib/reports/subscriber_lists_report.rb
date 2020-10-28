class Reports::SubscriberListsReport
  attr_reader :date

  CSV_HEADERS = %i[title
                   slug
                   matching_criteria
                   created_at
                   individual_subscribers
                   daily_subscribers
                   weekly_subscribers
                   matched_content_changes_for_date
                   matched_messages_for_date
                   unsubscribed].freeze

  def initialize(date)
    @date = Time.zone.parse(date)
  end

  def call
    CSV do |csv|
      csv << CSV_HEADERS

      SubscriberList.where("created_at < ?", date.end_of_day).find_each do |list|
        csv << export_list_row(list)
      end
    end
  end

private

  def export_list_row(list)
    unsubscribed_count = list.subscriptions.where("ended_at <= ?", date.end_of_day).count
    scope = list.subscriptions.active_on(date.end_of_day)

    [list.title,
     list.slug,
     criteria(list),
     list.created_at,
     scope.immediately.count,
     scope.daily.count,
     scope.weekly.count,
     matched_content_changes_count(list),
     matched_messages_count(list),
     unsubscribed_count]
  end

  def criteria(list)
    list.as_json(root: false,
                 only: %i[links
                          tags
                          email_document_supertype
                          government_document_supertype
                          document_type]).to_json
  end

  def matched_content_changes_count(list)
    MatchedContentChange
      .where(subscriber_list: list)
      .where("created_at > ? AND created_at <= ?", date.beginning_of_day, date.end_of_day)
      .count
  end

  def matched_messages_count(list)
    MatchedMessage
      .where(subscriber_list: list)
      .where("created_at > ? AND created_at <= ?", date.beginning_of_day, date.end_of_day)
      .count
  end
end
