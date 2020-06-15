RSpec.describe SubscriptionContent do
  describe "validations" do
    it "is valid for the default factory" do
      expect(build(:subscription_content)).to be_valid
    end

    it "is valid with a message" do
      expect(build(:subscription_content, :with_message)).to be_valid
    end

    it "is invalid with a message and a content_change" do
      subscription_content = build(
        :subscription_content,
        message: build(:message),
        content_change: build(:content_change),
      )
      expect(subscription_content).to be_invalid
    end

    it "is invalid without a message or a content_change" do
      subscription_content = build(
        :subscription_content,
        message: nil,
        content_change: nil,
      )
      expect(subscription_content).to be_invalid
    end
  end

  describe ".import!" do
    let(:content_changes) { create_list(:content_change, 15) }
    let(:subscription) { create(:subscription) }
    let(:columns) { %i[content_change_id subscription_id] }
    let(:rows) { content_changes.map { |c| [c.id, subscription.id] } }

    it "can import a lot of items" do
      expect {
        described_class.import!(columns,
                                rows,
                                on_duplicate_key_ignore: true,
                                batch_size: 5)
      }
        .to change { SubscriptionContent.count }
        .by(15)
    end

    it "can recover when there are duplicates" do
      rows.shuffle.take(5).each do |(content_change_id, subscription_id)|
        create(
          :subscription_content,
          content_change_id: content_change_id,
          subscription_id: subscription_id,
        )
      end

      expect {
        described_class.import!(columns,
                                rows,
                                on_duplicate_key_ignore: true)
      }
        .to change { SubscriptionContent.count }
        .by(10)
    end
  end

  describe ".populate_for_content" do
    let(:email) { create(:email) }
    let(:subscriptions) { create_list(:subscription, 2) }

    it "adds records when given a content change" do
      content_change = create(:content_change)
      # setting usec 0 to avoid Ruby/Postgres preceision differences
      Timecop.freeze(Time.zone.now.change(usec: 0)) do
        records = subscriptions.map do |s|
          { subscription_id: s.id, email_id: email.id }
        end

        expect { described_class.populate_for_content(content_change, records) }
          .to change { SubscriptionContent.count }.by(2)

        expect(SubscriptionContent.last)
          .to have_attributes(subscription_id: subscriptions.last.id,
                              email_id: email.id,
                              content_change_id: content_change.id,
                              message_id: nil,
                              created_at: Time.zone.now,
                              updated_at: Time.zone.now)
      end
    end

    it "adds records when given a message" do
      message = create(:message)
      # setting usec 0 to avoid Ruby/Postgres preceision differences
      Timecop.freeze(Time.zone.now.change(usec: 0)) do
        records = subscriptions.map do |s|
          { subscription_id: s.id, email_id: email.id }
        end

        expect { described_class.populate_for_content(message, records) }
          .to change { SubscriptionContent.count }.by(2)

        expect(SubscriptionContent.last)
          .to have_attributes(subscription_id: subscriptions.last.id,
                              email_id: email.id,
                              content_change_id: nil,
                              message_id: message.id,
                              created_at: Time.zone.now,
                              updated_at: Time.zone.now)
      end
    end

    it "raise an ArgumentError when given a different object" do
      records = subscriptions.map do |s|
        { subscription_id: s.id, email_id: email.id }
      end
      expect { described_class.populate_for_content({}, records) }
        .to raise_error(ArgumentError, "Expected Hash to be a ContentChange or a Message")
    end

    it "raises an error when records already exist" do
      content_change = create(:content_change)
      records = subscriptions.map do |s|
        { subscription_id: s.id, email_id: email.id }
      end

      create(:subscription_content,
             content_change: content_change,
             email: email,
             subscription: subscriptions.last)

      expect { described_class.populate_for_content(content_change, records) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
