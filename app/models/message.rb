class Message < ApplicationRecord
  include SymbolizeJSON

  has_many :matched_messages
  has_many :subscription_contents

  validates_presence_of :title, :body, :criteria_rules, :govuk_request_id
  validates :criteria_rules, criteria_schema: true, allow_blank: true
  validates :sender_message_id, uuid: true, uniqueness: true, allow_nil: true

  validates_each :url, allow_nil: true do |record, attribute, value|
    parsed = URI.parse(value)
    if parsed.absolute? && parsed.scheme != "https"
      record.errors.add(attribute, "must use https")
    elsif parsed.relative? && (parsed.host || parsed.path[0] != "/")
      record.errors.add(attribute, "must be a root-relative URL or an absolute URL")
    end
  rescue URI::InvalidURIError
    record.errors.add(attribute, "must be a valid URL")
  end

  enum priority: { normal: 0, high: 1 }

  def mark_processed!
    update!(processed_at: Time.now)
  end

  def processed?
    processed_at.present?
  end
end
