RSpec.describe DeliveryAttempt, type: :model do
  shared_examples "is marked as a failure" do
    it "is marked as a failure" do
      expect(subject.failure?).to be_truthy
    end
  end

  describe "validations" do
    subject { create(:delivery_attempt) }

    it "is valid for the default factory" do
      expect(subject).to be_valid
    end
  end

  context "with a permanent failure" do
    subject { create(:delivery_attempt, status: :permanent_failure) }

    include_examples "is marked as a failure"

    it "is marked as remove the subscriber" do
      expect(subject.should_remove_subscriber?).to be_truthy
    end
  end

  context "with a temporary failure" do
    subject { create(:delivery_attempt, status: :temporary_failure) }

    include_examples "is marked as a failure"
  end

  context "with a technical failure" do
    subject { create(:delivery_attempt, status: :technical_failure) }

    include_examples "is marked as a failure"

    it "is marked as should report failure" do
      expect(subject.should_report_failure?).to be_truthy
    end
  end

  describe ".finished_sending_at" do
    subject { delivery_attempt.finished_sending_at }

    context "when email is sent" do
      let(:delivery_attempt) { build(:delivered_delivery_attempt) }
      it { is_expected.to eq delivery_attempt.sent_at }
    end

    context "when email failed" do
      let(:delivery_attempt) { build(:permanent_failure_delivery_attempt) }
      it { is_expected.to eq delivery_attempt.completed_at }
    end

    context "when email is sending" do
      let(:delivery_attempt) { build(:sending_delivery_attempt) }
      it { is_expected.to be_nil }
    end
  end

  describe ".final_status?" do
    subject { described_class.final_status?(status) }
    context "when given a final status" do
      let(:status) { :delivered }
      it { is_expected.to be true }
    end

    context "when given a non final status" do
      let(:status) { :sending }
      it { is_expected.to be false }
    end
  end

  describe ".has_final_status?" do
    subject { build(:delivery_attempt, status: status).has_final_status? }

    context "when it has a final status" do
      let(:status) { "delivered" }
      it { is_expected.to be true }
    end

    context "when it has a non final status" do
      let(:status) { "sending" }
      it { is_expected.to be false }
    end
  end
end
