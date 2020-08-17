RSpec.describe DigestRun do
  context "with valid parameters" do
    it "can be created" do
      expect {
        described_class.create(
          attributes_for(:digest_run),
        )
      }.to change { DigestRun.count }.from(0).to(1)
    end

    context "with no environment vars set" do
      context "daily" do
        it "sets starts_at to 8am on date - 1.day" do
          date = 2.days.ago
          instance = described_class.create!(date: date, range: "daily")

          expect(instance.starts_at).to eq(
            Time.zone.parse("08:00", date - 1.day),
          )
        end

        it "sets ends_at to 8am on date" do
          date = 1.day.ago
          instance = described_class.create!(date: date, range: "daily")

          expect(instance.ends_at).to eq(
            Time.zone.parse("08:00", date),
          )
        end
      end

      context "weekly" do
        it "sets starts_at to 8am on date - 1.week" do
          date = 1.day.ago
          instance = described_class.create!(date: date, range: "weekly")

          expect(instance.starts_at).to eq(
            Time.zone.parse("08:00", (date - 1.week)),
          )
        end

        it "sets ends_at to 8am on date" do
          date = Date.current
          instance = described_class.create!(date: date, range: "weekly")

          expect(instance.ends_at).to eq(
            Time.zone.parse("08:00", date),
          )
        end
      end
    end

    context "configured with an env var" do
      around do |example|
        ClimateControl.modify(DIGEST_RANGE_HOUR: "10") do
          travel_to(Time.zone.parse("10:30")) { example.run }
        end
      end

      context "daily" do
        it "sets starts_at to the configured hour on date - 1.day" do
          date = 1.week.ago
          instance = described_class.create!(date: date, range: "daily")

          expect(instance.starts_at).to eq(
            Time.zone.parse("10:00", (date - 1.day)),
          )
        end

        it "sets ends_at to the configured hour on date" do
          date = 1.day.ago
          instance = described_class.create!(date: date, range: "daily")

          expect(instance.ends_at).to eq(
            Time.zone.parse("10:00", date),
          )
        end
      end

      context "weekly" do
        it "sets starts_at to the configured hour on date - 1.week" do
          date = Date.current
          instance = described_class.create!(date: date, range: "weekly")

          expect(instance.starts_at).to eq(
            Time.zone.parse("10:00", (date - 1.week)),
          )
        end

        it "sets ends_at to the configured hour on date" do
          date = 4.days.ago
          instance = described_class.create!(date: date, range: "weekly")

          expect(instance.ends_at).to eq(
            Time.zone.parse("10:00", date),
          )
        end
      end
    end

    describe "validations" do
      it "fails if the calculated ends_at is in the future" do
        travel_to(Time.zone.parse("07:00")) do
          instance = described_class.new(date: Date.current, range: "daily")
          instance.validate
          expect(instance.errors[:ends_at]).to eq(["must be in the past"])
        end
      end
    end
  end

  context "when we are in British Summer Time" do
    around do |example|
      travel_to("2018-03-31 07:30 UTC") { example.run }
    end

    it "creates a digest run without errors" do
      described_class.create!(date: Date.current, range: :daily)
    end
  end

  describe "#check_if_completed" do
    let(:digest_run) { create(:digest_run) }

    context "incomplete digest_run_subscribers" do
      before { create(:digest_run_subscriber, digest_run_id: digest_run.id) }

      it "doesn't mark the digest run as complete" do
        expect { digest_run.check_if_completed }
          .not_to change { digest_run.completed_at }
          .from(nil)
      end
    end

    context "no incomplete digest_run_subscribers" do
      let(:digest_run_subscriber) do
        create(:digest_run_subscriber, digest_run_id: digest_run.id, completed_at: Time.zone.now)
      end

      it "marks the digest run as completed based on the digest run subscriber time" do
        expect { digest_run.check_if_completed }
          .to change { digest_run.completed_at }
          .to(digest_run_subscriber.reload.completed_at)
      end
    end

    context "already completed digest run" do
      let(:completed_time) { Date.yesterday.midday }
      before { digest_run.update!(completed_at: completed_time) }

      it "doesn't change the completed at time" do
        expect { digest_run.check_if_completed }
          .not_to change { digest_run.completed_at }
          .from(completed_time)
      end
    end
  end
end
