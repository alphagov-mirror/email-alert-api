RSpec.describe ImmediateEmailGenerationService do
  describe ".call" do
    let(:content_change) { create(:content_change) }
    let(:subscriber_list) { create(:subscriber_list) }

    before do
      create(:matched_content_change,
             subscriber_list: subscriber_list,
             content_change: content_change)
    end

    it "generates emails for active, immediate subscribers" do
      create(:subscription, :ended, subscriber_list: subscriber_list)
      create(:subscription, :daily, subscriber_list: subscriber_list)
      immediate = create(:subscription, :immediately, subscriber_list: subscriber_list)

      expect { described_class.call(content_change) }
        .to change { Email.count }.by(1)
        .and change { SubscriptionContent.where(subscription: immediate).count }
        .by(1)
    end

    it "doesn't generate emails if there are no subscribers" do
      expect { described_class.call(content_change) }
        .not_to(change { Email.count })
    end

    it "queues DeliveryRequestWorkers" do
      create_list(:subscription, 2, subscriber_list: subscriber_list)
      allow(DeliveryRequestWorker).to receive(:perform_async_in_queue)

      described_class.call(content_change)

      email_ids = Email.order(created_at: :desc).pluck(:id)
      expect(DeliveryRequestWorker).to have_received(:perform_async_in_queue)
                                   .with(email_ids[0], queue: :delivery_immediate)
      expect(DeliveryRequestWorker).to have_received(:perform_async_in_queue)
                                   .with(email_ids[1], queue: :delivery_immediate)
    end

    context "when a content change is high priority" do
      let(:content_change) { create(:content_change, priority: "high") }

      it "puts the delivery request on the high priority queue" do
        create(:subscription, :immediately, subscriber_list: subscriber_list)
        allow(DeliveryRequestWorker).to receive(:perform_async_in_queue)

        described_class.call(content_change)
        expect(DeliveryRequestWorker)
          .to have_received(:perform_async_in_queue)
          .with(Email.last.id, queue: :delivery_immediate_high)
      end
    end

    context "when given a message" do
      let(:message) { create(:message) }

      before do
        create(:matched_message,
               subscriber_list: subscriber_list,
               message: message)
        allow(DeliveryRequestWorker).to receive(:perform_async_in_queue)
      end

      it "can create and queue emails" do
        create(:subscription, :immediately, subscriber_list: subscriber_list)
        allow(DeliveryRequestWorker).to receive(:perform_async_in_queue)

        expect { described_class.call(message) }
          .to change { Email.count }.by(1)
        expect(DeliveryRequestWorker)
          .to have_received(:perform_async_in_queue)
          .with(Email.last.id, queue: :delivery_immediate)
      end
    end
  end
end
