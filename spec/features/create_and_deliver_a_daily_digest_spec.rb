RSpec.describe "create and deliver a daily digest", type: :request do
  include UTMHelpers

  scenario do
    login_with_internal_app

    # create two subscriber lists with different links
    list_one_topic_id = "0eb5d0f0-d384-4f27-9da8-3f9e9b22a820"
    list_two_topic_id = "a915e039-070b-4633-813d-187af61cad7a"

    subscriber_list_one_id = create_subscriber_list(
      title: "Subscriber list one",
      links: {
        topics: { any: [list_one_topic_id] },
      },
    )

    subscriber_list_two_id = create_subscriber_list(
      title: "Subscriber list two",
      links: {
        topics: { any: [list_two_topic_id] },
      },
    )

    # create two daily subscribers, one subscribed to daily digests for both
    # subscriber_lists and the other for daily for subscriber_list_one only
    subscriber_one_address = "test-one@example.com"
    subscriber_two_address = "test-two@example.com"

    # subscriber that shouldn't receive a digest
    non_digest_subscriber_address = "test-three@example.com"

    subscribe_to_subscriber_list(
      subscriber_list_one_id,
      address: subscriber_one_address,
      frequency: Frequency::DAILY,
    )

    subscribe_to_subscriber_list(
      subscriber_list_two_id,
      address: subscriber_one_address,
      frequency: Frequency::DAILY,
    )

    subscribe_to_subscriber_list(
      subscriber_list_one_id,
      address: subscriber_two_address,
      frequency: Frequency::DAILY,
    )

    subscribe_to_subscriber_list(
      subscriber_list_one_id,
      address: non_digest_subscriber_address,
      frequency: Frequency::IMMEDIATELY,
    )

    # publish two items to each list
    travel_to(Time.zone.parse("2017-01-01 09:30")) do
      create_content_change(
        title: "Title one",
        description: "Description one",
        change_note: "Change note one",
        public_updated_at: "2017-01-01 10:00:00",
        links: { topics: [list_one_topic_id] },
      )
    end

    travel_to(Time.zone.parse("2017-01-01 09:31")) do
      create_message(
        title: "Title two",
        criteria_rules: [
          { type: "link", key: "topics", value: list_one_topic_id },
        ],
      )
    end

    travel_to(Time.zone.parse("2017-01-01 09:32")) do
      create_content_change(
        title: "Title three",
        description: "Description three",
        change_note: "Change note three",
        public_updated_at: "2017-01-01 09:00:00",
        links: {
          topics: [list_two_topic_id],
        },
      )
    end

    travel_to(Time.zone.parse("2017-01-01 09:33")) do
      create_content_change(
        title: "Title four",
        description: "Description four",
        change_note: "Change note four",
        public_updated_at: "2017-01-01 09:30:00",
        links: {
          topics: [list_two_topic_id],
        },
      )
    end

    content_changes = ContentChange.order(:created_at)

    first_digest_stub = stub_notify_request(
      subscriber_one_address,
      first_expected_email_body(
        content_changes[0],
      ),
      "Subscriber list one",
    )

    second_digest_stub = stub_notify_request(
      subscriber_one_address,
      second_expected_email_body(
        content_changes[1],
        content_changes[2],
      ),
      "Subscriber list two",
    )

    third_digest_stub = stub_notify_request(
      subscriber_two_address,
      third_expected_email_body(
        content_changes[0],
      ),
      "Subscriber list one",
    )

    travel_to(Time.zone.parse("2017-01-02 10:00")) do
      DailyDigestInitiatorWorker.new.perform
      Sidekiq::Worker.drain_all
    end

    expect(first_digest_stub).to have_been_requested
    expect(second_digest_stub).to have_been_requested
    expect(third_digest_stub).to have_been_requested
  end

  def url
    "http://www.dev.gov.uk/base-path?"
  end

  def stub_notify_request(email_address, email_body, title)
    body = hash_including(
      email_address: email_address,
      personalisation: hash_including(
        "subject" => "Daily update from GOV.UK for: #{title}",
        "body" => include(email_body),
      ),
    )

    stub_request(:post, "https://api.notifications.service.gov.uk/v2/notifications/email")
      .with(body: body)
      .to_return(body: {}.to_json)
  end

  def first_expected_email_body(content_change_one)
    <<~BODY
      Daily update from GOV.UK for:

      # Subscriber list one

      ---

      # [Title one](#{url}#{utm_params(content_change_one.id, 'daily')})

      Page summary:
      Description one

      Change made:
      Change note one

      Time updated:
      10:00am, 1 January 2017

      ---

      Title two

      Body

      ---

      # Why am I getting this email?

      You asked GOV.UK to send you one email a day about:

      Subscriber list one
    BODY
  end

  def second_expected_email_body(content_change_two, content_change_three)
    <<~BODY
      Daily update from GOV.UK for:

      # Subscriber list two

      ---

      # [Title three](#{url}#{utm_params(content_change_two.id, 'daily')})

      Page summary:
      Description three

      Change made:
      Change note three

      Time updated:
      9:00am, 1 January 2017

      ---

      # [Title four](#{url}#{utm_params(content_change_three.id, 'daily')})

      Page summary:
      Description four

      Change made:
      Change note four

      Time updated:
      9:30am, 1 January 2017

      ---

      # Why am I getting this email?

      You asked GOV.UK to send you one email a day about:

      Subscriber list two
    BODY
  end

  def third_expected_email_body(content_change_one)
    <<~BODY
      Daily update from GOV.UK for:

      # Subscriber list one

      ---

      # [Title one](#{url}#{utm_params(content_change_one.id, 'daily')})

      Page summary:
      Description one

      Change made:
      Change note one

      Time updated:
      10:00am, 1 January 2017

      ---

      Title two

      Body

      ---

      # Why am I getting this email?

      You asked GOV.UK to send you one email a day about:

      Subscriber list one
    BODY
  end
end
