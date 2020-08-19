RSpec.describe DigestInitiatorService do
  describe ".call" do
    around { |example| travel_to(Time.zone.parse("08:30")) { example.run } }

    context "daily" do
      let(:range) { Frequency::DAILY }

      context "when there is no daily DigestRun for the date" do
        it "creates one" do
          expect { described_class.call(range: range) }
            .to change { DigestRun.daily.count }.from(0).to(1)
        end

        it "marks the digest run as processed" do
          described_class.call(range: range)
          digest_run = DigestRun.last
          expect(digest_run.processed_at).to eq(Time.zone.now)
        end
      end

      context "when a DigestRun already exists" do
        it "doesn't create another one" do
          create(:digest_run, :daily, date: Date.current)

          described_class.call(range: range)

          expect(DigestRun.count).to eq(1)
        end
      end

      context "when the service is called multiple times" do
        it "only creates one DigestRun" do
          described_class.call(range: range)
          described_class.call(range: range)
          described_class.call(range: range)
          described_class.call(range: range)

          expect(DigestRun.count).to eq(1)
        end
      end

      context "with matched content" do
        let(:subscribers) { [create(:subscriber, id: 1), create(:subscriber, id: 2)] }

        before do
          allow(DigestRunSubscriberQuery).to receive(:call).and_return(subscribers)
          allow(DigestEmailGenerationWorker).to receive(:perform_async)
        end

        it "creates a DigestRunSubscriber for each subscriber" do
          described_class.call(range: range)
          expect(DigestRunSubscriber.all.map(&:subscriber_id)).to match([1, 2])
        end

        it "enqueues a DigestEmailGenerationWorker job" do
          expect(DigestEmailGenerationWorker)
            .to receive(:perform_async)
            .exactly(2).times

          described_class.call(range: range)
        end
      end

      it "records a metric for the delivery attempt" do
        expect(Metrics).to receive(:digest_initiator_service)
          .with("daily")

        described_class.call(range: range)
      end
    end

    context "weekly" do
      let(:range) { Frequency::WEEKLY }

      context "when there is no daily DigestRun for the date" do
        it "creates one" do
          expect { described_class.call(range: range) }
            .to change { DigestRun.weekly.count }.from(0).to(1)
        end
      end

      context "when a DigestRun already exists" do
        it "doesn't create another one" do
          create(:digest_run, :weekly, date: Date.current)

          described_class.call(range: range)

          expect(DigestRun.count).to eq(1)
        end
      end

      context "when the service is called multiple times" do
        it "only creates one DigestRun" do
          described_class.call(range: range)
          described_class.call(range: range)
          described_class.call(range: range)
          described_class.call(range: range)

          expect(DigestRun.count).to eq(1)
        end
      end
    end
  end
end
