FactoryBot.define do
  trait :skip_validation do
    to_create { |instance| instance.save!(validate: false) }
  end

  factory :content_change do
    content_id { SecureRandom.uuid }
    title { "title" }
    base_path { "government/base_path" }
    change_note { "change note" }
    description { "description" }
    links { {} }
    tags { {} }
    public_updated_at { Time.zone.now.to_s }
    email_document_supertype { "email document supertype" }
    government_document_supertype { "government document supertype" }
    sequence(:govuk_request_id) { |i| "request-id-#{i}" }
    document_type { "document type" }
    publishing_app { "publishing app" }

    trait :matched do
      transient do
        subscriber_list { build(:subscriber_list) }
      end

      after(:build) do |content_change, evaluator|
        content_change.matched_content_changes << evaluator.association(
          :matched_content_change,
          content_change: content_change,
          subscriber_list: evaluator.subscriber_list,
        )
      end
    end
  end

  factory :message do
    title { "Title" }
    body { "Body" }
    criteria_rules do
      [
        {
          type: "tag",
          key: "brexit_checklist_criteria",
          value: "eu-national",
        },
      ]
    end

    sequence(:govuk_request_id) { |i| "request-id-#{i}" }

    trait :matched do
      transient do
        subscriber_list { build(:subscriber_list) }
      end

      after(:build) do |message, evaluator|
        message.matched_messages << evaluator.association(
          :matched_message,
          message: message,
          subscriber_list: evaluator.subscriber_list,
        )
      end
    end
  end

  factory :delivery_attempt, aliases: [:sent_delivery_attempt] do
    email
    status { :sent }
    provider { :notify }

    factory :delivered_delivery_attempt do
      status { :delivered }
      sent_at { Time.zone.now }
      completed_at { Time.zone.now }
    end

    factory :undeliverable_failure_delivery_attempt do
      status { :undeliverable_failure }
      sent_at { nil }
      completed_at { Time.zone.now }
    end

    factory :provider_communication_failure_delivery_attempt do
      status { :provider_communication_failure }
      sent_at { nil }
      completed_at { Time.zone.now }
    end
  end

  factory :digest_run do
    date { 1.day.ago }
    range { Frequency::DAILY }

    trait :daily

    trait :weekly do
      range { Frequency::WEEKLY }
    end
  end

  factory :digest_run_subscriber do
    digest_run
    subscriber
  end

  factory :email, aliases: %i[unarchivable_email pending_email] do
    address { "test@example.com" }
    subject { "subject" }
    body { "body" }

    factory :archivable_email do
      status { :sent }
    end

    factory :archived_email do
      status { :sent }
      archived_at { 1.day.ago }
    end

    factory :deleteable_email do
      status { :sent }
      archived_at { 14.days.ago }
    end
  end

  factory :subscriber do
    sequence(:address) { |i| "test-#{i}@example.com" }

    trait :activated

    trait :deactivated do
      deactivated_at { Time.zone.now }
    end

    trait :nullified do
      address { nil }
      deactivated_at { Time.zone.now }
    end
  end

  factory :subscriber_list do
    sequence(:title) { |n| "title #{n}" }
    sequence(:slug) { |n| "title-#{n}" }
    tags { { topics: { any: ["motoring/road_rage"] } } }
    created_at { 1.year.ago }

    trait :travel_advice do
      links { { countries: { any: [SecureRandom.uuid] } } }
    end

    trait :medical_safety_alert do
      tags { { format: %w[medical_safety_alert], alert_type: %w[devices drugs field-safety-notices company-led-drugs] } }
    end

    factory :subscriber_list_with_subscribers do
      transient do
        subscriber_count { 5 }
      end

      after(:create) do |list, evaluator|
        create_list(:subscriber, evaluator.subscriber_count, :activated, subscriber_lists: [list])
      end
    end

    factory :subscriber_list_with_invalid_tags do
      tags do
        {
          organisations: { any: %w[bar] },
          case_type: { any: %w[*!123] },
        }
      end

      transient do
        subscriber_count { 5 }
      end

      after(:create) do |list, evaluator|
        list = build_list(:subscriber, evaluator.subscriber_count, subscriber_lists: [list])
        list.each { |item| item.save!(validate: false) }
      end
    end
  end

  factory :subscription do
    subscriber
    subscriber_list
    frequency { Frequency::IMMEDIATELY }

    trait :immediately

    trait :daily do
      frequency { Frequency::DAILY }
    end

    trait :weekly do
      frequency { Frequency::WEEKLY }
    end

    trait :ended do
      ended_at { Time.zone.now }
      ended_reason { :unsubscribed }
    end

    trait :unpublished do
      ended_reason { "unpublished" }
    end
  end

  factory :subscription_content do
    subscription
    content_change

    trait :with_message do
      content_change { nil }
      message
    end

    trait :with_archivable_email do
      association :email, factory: :archivable_email

      after(:create) do |subscription_content, _evaluator|
        subscription_content.email.update(subscriber_id: subscription_content.subscription.subscriber.id)
      end
    end
  end

  factory :matched_content_change do
    content_change
    subscriber_list
  end

  factory :matched_message do
    message
    subscriber_list
  end

  factory :user

  factory :content_item do
    sequence(:path) { |n| "/content-item-#{n}" }

    initialize_with { new(path) }
    skip_create
  end

  factory :client_notification,
          class: Notifications::Client::Notification do
    initialize_with do
      new(body)
    end

    body do
      {
        "id" => "f163deaf-2d3f-4ec6-98fc-f23fa511518f",
        "reference" => "ref_123",
        "email_address" => "123@notify.com",
        "type" => "email",
        "status" => "delivered",
        "template" =>
          {
            "id" => "cb633abc-6ae6-4843-ae6f-82ca500b6de2",
            "uri" => "/v2/templates/5e427b42-4e98-46f3-a047-32c4a87d26bb",
            "version" => 1,
          },
        "body" => "Body of the message",
        "subject" => "Changes to this document",
        "created_at" => "2019-01-29T11:12:30.12354Z",
        "sent_at" => "2019-01-29T11:12:40.12354Z",
        "completed_at" => "2019-01-29T11:12:52.12354Z",
        "created_by_name" => "A. Sender",
      }
    end
  end

  factory :client_notifications_collection,
          class: Notifications::Client::NotificationsCollection do
    initialize_with do
      new(body)
    end

    body do
      {
        "links" => {
          "current" => "/v2/notifications?page=3&template_type=email&status=delivered",
          "next" => "/v2/notifications?page=3&template_type=email&status=delivered",
        },
        "notifications" => 1.times.map do
          attributes_for(:client_notification)[:body]
        end,
      }
    end
  end

  factory :empty_client_notifications_collection,
          class: Notifications::Client::NotificationsCollection do
    initialize_with do
      new(body)
    end
    body do
      {
        "links" => {},
        "notifications" => {},
      }
    end
  end

  factory :client_request_error,
          class: Notifications::Client::RequestError do
    code { "400" }
    body do
      {
        "status_code" => 400,
        "errors" => ["error" => "ValidationError",
                     "message" => "bad status is not one of [created, sending, sent, delivered, pending, failed, technical-failure, temporary-failure, permanent-failure, accepted, received]"],
      }
    end

    initialize_with do
      new(
        OpenStruct.new(code: code, body: body.to_json),
      )
    end
  end
end
