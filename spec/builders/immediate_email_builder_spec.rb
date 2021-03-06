RSpec.describe ImmediateEmailBuilder do
  describe ".call" do
    let(:subscriber_list) { build(:subscriber_list, title: "My List") }
    let(:subscription) { build(:subscription, subscriber_list: subscriber_list) }
    let(:subscriber) { subscription.subscriber }

    before do
      allow(FooterPresenter).to receive(:call)
        .with(subscriber, subscription)
        .and_return("presented_footer")
    end

    it "raises an ArgumentError when given an empty collection of parameters" do
      expect { described_class.call([]) }.to raise_error(ArgumentError)
    end

    context "for a content change" do
      let(:content_change) { build(:content_change, title: "Title") }

      subject(:email) do
        import = described_class.call(content_change, [subscription])
        Email.find(import.first)
      end

      before do
        allow(ContentChangePresenter).to receive(:call)
          .with(content_change, subscription)
          .and_return("presented_content_change")
      end

      it "creates an email" do
        expect(email.subject).to eq("Update from GOV.UK for: Title")
        expect(email.subscriber_id).to eq(subscriber.id)

        expect(email.body).to eq(
          <<~BODY,
            Update from GOV.UK for:

            # My List

            ---

            presented_content_change

            ---

            presented_footer
          BODY
        )
      end
    end

    context "for a message" do
      let(:message) { build(:message, title: "Title") }

      subject(:email) do
        import = described_class.call(message, [subscription])
        Email.find(import.first)
      end

      before do
        allow(MessagePresenter).to receive(:call)
          .with(message, subscription)
          .and_return("presented_message")
      end

      it "creates an email" do
        expect(email.subject).to eq("Update from GOV.UK for: Title")
        expect(email.subscriber_id).to eq(subscriber.id)

        expect(email.body).to eq(
          <<~BODY,
            Update from GOV.UK for:

            # My List

            ---

            presented_message

            ---

            presented_footer
          BODY
        )
      end
    end

    context "when the list has a source URL" do
      let(:content_change) { build(:content_change, title: "Title") }

      subject(:email) do
        import = described_class.call(content_change, [subscription])
        Email.find(import.first)
      end

      before do
        allow(ContentChangePresenter).to receive(:call)
          .with(content_change, subscription)
          .and_return("presented_content_change")

        allow(SourceUrlPresenter).to receive(:call).and_return("Presented URL")
      end

      it "includes it in the body" do
        expect(email.body).to include(
          <<~BODY,
            ---

            presented_content_change

            Presented URL

            ---
          BODY
        )
      end
    end
  end
end
