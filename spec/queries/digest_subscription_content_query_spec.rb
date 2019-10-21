RSpec.describe DigestSubscriptionContentQuery do
  describe ".call" do
    let(:subscriber) { create(:subscriber) }
    let(:ends_at) { Time.zone.parse("2017-01-02 08:00") }
    let(:digest_run) { create(:digest_run, :daily, date: ends_at) }

    subject(:results) { described_class.call(subscriber, digest_run) }

    context "when there are no results" do
      it { is_expected.to be_empty }
    end

    context "with an active matching subscription" do
      let(:subscriber_list) { create(:subscriber_list) }
      let!(:subscription) do
        create(:subscription,
               :daily,
               subscriber_list: subscriber_list,
               subscriber: subscriber)
      end

      it "returns the content changes and messages" do
        content_change = create(:content_change,
                                :matched,
                                subscriber_list: subscriber_list,
                                created_at: digest_run.starts_at)
        message = create(:message,
                         :matched,
                         subscriber_list: subscriber_list,
                         created_at: digest_run.starts_at)

        expect(results.count).to eq(1)
        expect(results.first.to_h)
          .to match(subscription_id: subscription.id,
                    subscriber_list_title: subscriber_list.title,
                    subscriber_list_url: subscriber_list.url,
                    subscriber_list_description: subscriber_list.description,
                    content: [content_change, message])
      end

      it "returns the content ordered by created_at time" do
        content_change1 = create(:content_change,
                                 :matched,
                                 subscriber_list: subscriber_list,
                                 created_at: digest_run.starts_at)
        content_change2 = create(:content_change,
                                 :matched,
                                 subscriber_list: subscriber_list,
                                 created_at: digest_run.starts_at + 20.minutes)
        message1 = create(:message,
                          :matched,
                          subscriber_list: subscriber_list,
                          created_at: digest_run.starts_at + 25.minutes)
        message2 = create(:message,
                          :matched,
                          subscriber_list: subscriber_list,
                          created_at: digest_run.starts_at + 10.minutes)
        expect(results.first.content)
          .to match([content_change1, message2, content_change2, message1])
      end

      it "returns only one content change if there are multiple with same content_id" do
        content_id = SecureRandom.uuid
        content_change1 = create(:content_change,
                                 :matched,
                                 content_id: content_id,
                                 subscriber_list: subscriber_list,
                                 created_at: digest_run.starts_at)
        create(:content_change,
               :matched,
               content_id: content_id,
               subscriber_list: subscriber_list,
               created_at: digest_run.starts_at + 20.minutes)

        expect(results.first.content).to match([content_change1])
      end
    end

    context "with multiple subscriber lists" do
      let(:subscriber_list1) { create(:subscriber_list, title: "Subscriber List A") }
      let(:subscriber_list2) { create(:subscriber_list, title: "Subscriber List B", url: "/example", description: "Description") }

      let!(:subscription1) do
        create(:subscription,
               :daily,
               subscriber_list: subscriber_list1,
               subscriber: subscriber)
      end

      let!(:subscription2) do
        create(:subscription,
               :daily,
               subscriber_list: subscriber_list2,
               subscriber: subscriber)
      end

      it "returns each subscriber list ordered by title" do
        content_change1 = create(:content_change,
                                 :matched,
                                 subscriber_list: subscriber_list1,
                                 created_at: digest_run.starts_at)

        content_change2 = create(:content_change,
                                 :matched,
                                 subscriber_list: subscriber_list2,
                                 created_at: digest_run.starts_at)

        expect(results.count).to eq(2)
        expect(results.first.to_h)
          .to match(subscription_id: subscription1.id,
                    subscriber_list_title: subscriber_list1.title,
                    subscriber_list_url: subscriber_list1.url,
                    subscriber_list_description: subscriber_list1.description,
                    content: [content_change1])

        expect(results.last.to_h)
          .to match(subscription_id: subscription2.id,
                    subscriber_list_title: subscriber_list2.title,
                    subscriber_list_url: subscriber_list2.url,
                    subscriber_list_description: subscriber_list2.description,
                    content: [content_change2])
      end

      it "returns a message only once if it's in two lists" do
        message = create(:message, created_at: digest_run.starts_at)
        create(:matched_message, message: message, subscriber_list: subscriber_list1)
        create(:matched_message, message: message, subscriber_list: subscriber_list2)

        expect(results.count).to eq(1)
        expect(results.first.to_h)
          .to match(subscription_id: subscription1.id,
                    subscriber_list_title: subscriber_list1.title,
                    subscriber_list_url: subscriber_list1.url,
                    subscriber_list_description: subscriber_list1.description,
                    content: [message])
      end
    end

    context "with an inactive matching subscription" do
      let(:subscriber_list) { create(:subscriber_list) }
      let!(:subscription) do
        create(:subscription,
               :daily,
               :ended,
               subscriber_list: subscriber_list,
               subscriber: subscriber)
      end

      before do
        create(:content_change,
               :matched,
               subscriber_list: subscriber_list,
               created_at: digest_run.starts_at)
      end

      it { is_expected.to be_empty }
    end
  end
end
