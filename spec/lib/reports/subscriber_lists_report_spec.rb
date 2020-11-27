RSpec.describe Reports::SubscriberListsReport do
  let(:created_at) { Time.zone.parse("2020-06-15").midday }

  before do
    list = create(:subscriber_list, created_at: created_at, title: "list 1", slug: "list-1")

    create(:subscription, :immediately, subscriber_list: list, created_at: created_at)
    create(:subscription, :daily, subscriber_list: list, created_at: created_at)
    create(:subscription, :weekly, subscriber_list: list, created_at: created_at)
    create(:subscription, :ended, ended_at: created_at, subscriber_list: list, created_at: created_at)

    create(:matched_content_change, subscriber_list: list, created_at: created_at)
    create(:matched_message, subscriber_list: list, created_at: created_at)
  end

  it "returns data around active lists for the given date" do
    expected_criteria_bits = '{"document_type":"","tags":{"topics":{"any":["motoring/road_rage"]}},' \
      '"links":{},"email_document_supertype":"","government_document_supertype":""}'

    expected = CSV.generate do |csv|
      csv << Reports::SubscriberListsReport::CSV_HEADERS
      csv << ["list 1", "list-1", expected_criteria_bits, created_at, 1, 1, 1, 1, 1, 1]
    end

    expect { described_class.new("2020-06-15").call }.to output(expected).to_stdout
  end

  it "raises an error if the date is invalid" do
    expect { described_class.new("blahhh").call }
      .to raise_error("Invalid date")
  end

  it "raises an error if the date isn't in the past" do
    expect { described_class.new(Time.zone.today.to_s).call }
      .to raise_error("Date must be in the past")
  end

  it "raises an error if the date isn't within a year old" do
    expect { described_class.new("2019-05-01").call }
      .to raise_error("Date must be within a year old")
  end
end
