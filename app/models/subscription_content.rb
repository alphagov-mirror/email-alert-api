class SubscriptionContent < ApplicationRecord
  belongs_to :subscription
  belongs_to :content_change, optional: true
  belongs_to :message, optional: true
  belongs_to :digest_run_subscriber, optional: true
  belongs_to :email, optional: true

  scope :immediate, -> { where(digest_run_subscriber_id: nil) }
  scope :digest, -> { where.not(digest_run_subscriber_id: nil) }

  validate :presence_of_content_change_or_message

  def self.populate_for_content(content, records)
    base = case content
           when ContentChange
             { content_change_id: content.id }
           when Message
             { message_id: content.id }
           else
             raise ArgumentError, "Expected #{content.class.name} to be a "\
                                  "ContentChange or a Message"
           end

    now = Time.zone.now

    attributes = records.map do |record|
      base.merge(created_at: now, updated_at: now).merge(record)
    end

    SubscriptionContent.insert_all!(attributes)
  end

  def presence_of_content_change_or_message
    has_content_change = content_change_id.present? || content_change.present?
    has_message = message_id.present? || message.present?

    if has_content_change && has_message
      errors.add(:base, "cannot be associated with a content_change and a message")
    end

    if !has_content_change && !has_message
      errors.add(:base, "must be associated with a content_change or a message")
    end
  end
end
