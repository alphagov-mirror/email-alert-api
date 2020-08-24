RSpec.describe "bulk_email" do
  describe "brexit_subscribers" do
    let(:tags) { { brexit_checklist_criteria: { any: %w[visiting-eu] } } }
    let!(:list) { create(:subscriber_list, tags: tags) }

    before do
      Rake::Task["bulk_email:brexit_subscribers"].reenable
    end

    around(:each) do |example|
      ClimateControl.modify(SUBJECT: "subject", BODY: "body") do
        example.run
      end
    end

    it "builds emails for a subscriber list" do
      expect(BulkSubscriberListEmailBuilder)
        .to receive(:call)
        .with(subject: "subject",
              body: "body",
              subscriber_lists: [list])
        .and_call_original

      Rake::Task["bulk_email:brexit_subscribers"].invoke("not_dry_run")
    end

    it "enqueues the emails for delivery" do
      allow(BulkSubscriberListEmailBuilder).to receive(:call)
        .and_return([1, 2])

      expect(DeliveryRequestWorker)
        .to receive(:perform_async_in_queue)
        .with(1, queue: :delivery_immediate)

      expect(DeliveryRequestWorker)
        .to receive(:perform_async_in_queue)
        .with(2, queue: :delivery_immediate)

      Rake::Task["bulk_email:brexit_subscribers"].invoke("not_dry_run")
    end

    context "dry run" do
      let(:task) { Rake::Task["bulk_email:brexit_subscribers"].invoke }
      let(:message) { "This task is in dry run mode. It would have queued 2 emails for delivery" }

      it "does not enqueue emails for delivery" do
        allow(BulkSubscriberListEmailBuilder).to receive(:call)
          .and_return([1, 2])

        expect(DeliveryRequestWorker)
          .not_to receive(:perform_async_in_queue)
          .with(1, queue: :delivery_immediate)

        expect(DeliveryRequestWorker)
          .not_to receive(:perform_async_in_queue)
          .with(2, queue: :delivery_immediate)

        expect { task }.to output(message).to_stdout
      end
    end
  end

  describe "for_lists" do
    before do
      Rake::Task["bulk_email:for_lists"].reenable
    end

    around(:each) do |example|
      ClimateControl.modify(SUBJECT: "subject", BODY: "body") do
        example.run
      end
    end

    it "builds emails for a subscriber list" do
      subscriber_list = create(:subscriber_list)

      expect(BulkSubscriberListEmailBuilder)
        .to receive(:call)
        .with(subject: "subject",
              body: "body",
              subscriber_lists: [subscriber_list])
        .and_call_original

      Rake::Task["bulk_email:for_lists"].invoke(subscriber_list.id)
    end

    it "enqueues the emails for delivery" do
      subscriber_list = create(:subscriber_list)

      allow(BulkSubscriberListEmailBuilder).to receive(:call)
        .and_return([1, 2])

      expect(DeliveryRequestWorker)
        .to receive(:perform_async_in_queue)
        .with(1, queue: :delivery_immediate)

      expect(DeliveryRequestWorker)
        .to receive(:perform_async_in_queue)
        .with(2, queue: :delivery_immediate)

      Rake::Task["bulk_email:for_lists"].invoke(subscriber_list.id)
    end
  end
end
