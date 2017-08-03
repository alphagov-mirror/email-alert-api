require "csv"

class NotificationReport
  def self.all
    new(NotificationLog.all)
  end

  attr_accessor :scope

  def initialize(scope)
    self.scope = scope
  end

  def entries
    @entries ||= scope
      .distinct(:govuk_request_id)
      .pluck(:govuk_request_id)
      .map { |id| Entry.new(id, scope.where(govuk_request_id: id)) }
  end

  def print
    entries.each { |entry| Printer.print(entry) }

    puts "\nNumber of mismatched entries / number of total entries"
    puts "#{total_mismatch_count}/#{entries.count}"

    puts "\nTop 10 topics that were only matched in email-alert-api"
    top_n(all_email_alert_api_topic_mismatches).each do |topic, count|
      puts "  #{topic}: #{count} times"
    end

    puts "\nTop 10 topics that were only matched in govuk-delivery"
    top_n(all_gov_uk_delivery_topic_mismatches).each do |topic, count|
      puts "  #{topic}: #{count} times"
    end
  end

  def export_csv
    CsvExporter.call(entries)
  end

private

  def total_mismatch_count
    entries.count - matching_entries.count
  end

  def matching_entries
    entries.select(&:all_ok?)
  end

  def all_email_alert_api_topic_mismatches
    entries.flat_map(&:topics_matched_in_email_alert_api_only)
  end

  def all_gov_uk_delivery_topic_mismatches
    entries.flat_map(&:topics_matched_in_govuk_delivery_only)
  end

  def top_n(array, n = 10)
    array
      .group_by(&:itself)
      .map { |element, arr| [element, arr.size] }
      .sort_by { |_, count| -count }
      .take(n)
  end

  class Entry
    attr_accessor :request_id, :records

    def initialize(request_id, records)
      self.request_id = request_id
      self.records = records.order(:id)
    end

    def all_ok?
      (
        email_alert_api_notifications.count == 1 &&
        email_alert_api_notifications_have_the_same_topics &&
        gov_uk_delivery_notifications.count == 1 &&
        gov_uk_delivery_notifications_have_the_same_topics &&
        topics_matched_in_both_systems.count > 0 &&
        topics_matched_in_email_alert_api_only.count == 0 &&
        topics_matched_in_govuk_delivery_only.count == 0
        ) ||
      gov_uk_delivery_notifications.none?
    end

    def email_alert_api_notifications
      records.where(emailing_app: "email_alert_api")
    end

    def gov_uk_delivery_notifications
      records.where(emailing_app: "gov_uk_delivery")
    end

    def email_alert_api_notifications_have_the_same_topics
      email_alert_api_notifications.map(&:gov_delivery_ids).uniq.size <= 1
    end

    def gov_uk_delivery_notifications_have_the_same_topics
      gov_uk_delivery_notifications.map(&:gov_delivery_ids).uniq.size <= 1
    end

    def topics_matched_in_both_systems
      email_alert_api_topics & gov_uk_delivery_topics
    end

    def topics_matched_in_email_alert_api_only
      email_alert_api_topics - gov_uk_delivery_topics
    end

    def topics_matched_in_govuk_delivery_only
      gov_uk_delivery_topics - email_alert_api_topics
    end

  private

    def email_alert_api_topics
      @email_alert_api_topics ||= (
        notification = email_alert_api_notifications.last
        notification ? notification.gov_delivery_ids : []
      )
    end

    def gov_uk_delivery_topics
      @gov_uk_delivery_topics ||= (
        notification = gov_uk_delivery_notifications.last
        notification ? notification.gov_delivery_ids : []
      )
    end
  end

  class CsvExporter
    PATH = Rails.root.join("public", "data", "notification_report.csv")
    HEADINGS = %w(
      govuk_request_id
      content_id
      document_type
      email_doc_supertype
      govt_doc_supertype
      created_at
      all_ok?
      email_alert_api_notifications.count
      gov_uk_delivery_notifications.count
      email_alert_api_notifications_have_the_same_topics
      gov_uk_delivery_notifications_have_the_same_topics
      topics_matched_in_both_systems
      topics_matched_in_email_alert_api_only
      topics_matched_in_govuk_delivery_only
    ).freeze

    def self.call(entries)
      File.open(PATH, "w") do |file|
        new(entries).export(file)
      end
    end

    attr_reader :entries, :path

    def initialize(entries)
      @entries = entries
    end

    def export(io)
      output = CSV.generate do |csv|
        csv << HEADINGS
        entries.each do |entry|
          csv << format(entry)
        end
      end
      io.write(output)
    end

  private

    def format(entry)
      [
        entry.request_id,
        notification_for(entry).content_id,
        notification_for(entry).document_type,
        notification_for(entry).email_document_supertype,
        notification_for(entry).government_document_supertype,
        notification_for(entry).created_at,
        entry.all_ok?,
        entry.email_alert_api_notifications.count,
        entry.gov_uk_delivery_notifications.count,
        entry.email_alert_api_notifications_have_the_same_topics,
        entry.gov_uk_delivery_notifications_have_the_same_topics,
        entry.topics_matched_in_both_systems.join(","),
        entry.topics_matched_in_email_alert_api_only.join(","),
        entry.topics_matched_in_govuk_delivery_only.join(","),
      ]
    end

    def notification_for(entry)
      entry.email_alert_api_notifications.last || entry.gov_uk_delivery_notifications.last
    end
  end

  module Printer
    TICK = "\e[32m✓\e[0m"
    CROSS = "\e[31m✗\e[0m"

    def self.print(entry)
      io = StringIO.new

      notification = entry.email_alert_api_notifications.last ||
                     entry.gov_uk_delivery_notifications.last

      io.puts "    content_id: #{notification.content_id}"
      io.puts "    document_type: #{notification.document_type}"
      io.puts "    email_doc_supertype: #{notification.email_document_supertype}"
      io.puts "    govt_doc_supertype: #{notification.government_document_supertype}"
      io.puts "    created_at: #{notification.created_at}"

      count_1 = entry.email_alert_api_notifications.count
      io.puts "  #{status(count_1 == 1)} #{count_1} notifications from email-alert-api"

      same_1 = entry.email_alert_api_notifications_have_the_same_topics
      io.puts "    #{status(same_1)} topics are #{same_1 ? "the same" : "different"} for these notifications"

      count_2 = entry.gov_uk_delivery_notifications.count
      io.puts "  #{status(count_2 == 1)} #{count_2} notifications from govuk-delivery"

      same_2 = entry.gov_uk_delivery_notifications_have_the_same_topics
      io.puts "    #{status(same_2)} topics are #{same_2 ? "the same" : "different"} for these notifications"

      count_3 = entry.topics_matched_in_both_systems.count
      io.puts "  #{status(count_3 > 0)} #{count_3} topics matched in both systems"

      count_4 = entry.topics_matched_in_email_alert_api_only.count
      io.puts "  #{status(count_4 == 0)} #{count_4} topics matched in email-alert-api but not in govuk-delivery"

      entry.topics_matched_in_email_alert_api_only.each do |topic|
        io.puts "      #{topic}: #{info(topic)}"
      end

      count_5 = entry.topics_matched_in_govuk_delivery_only.count
      io.puts "  #{status(count_5 == 0)} #{count_5} topics matched in govuk-delivery but not in email-alert-api"

      puts "#{status(entry.all_ok?)} request_id: #{entry.request_id}"
      puts io.string unless entry.all_ok?
    end

    def self.info(topic)
      @info ||= {}

      unless @info.key?(topic)
        list = SubscriberList.find_by(gov_delivery_id: topic)
        @info[topic] = list ? "#{list.title} #{list.subscriber_count} subscribers" : "<unknown>"
      end

      @info[topic]
    end

    def self.status(bool)
      bool ? TICK : CROSS
    end
  end
end
