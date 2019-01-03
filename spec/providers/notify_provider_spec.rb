RSpec.describe NotifyProvider do
  describe ".get_notify_email_status" do
    before do
      stub_request(
        :get,
        "https://fake-notify/v2/notifications/#{id}"
      ).to_return(body: mocked_response.to_json)
    end

    let(:id) {
      "1"
    }

    let(:mocked_response) {
      attributes_for(:client_notification)[:body]
    }

    it "returns the response object for an email id" do
      client = instance_double("Notifications::Client")
      allow(client).to receive(:get_notification).and_return(mocked_response)

      notification = client.get_notification(id)

      expect(notification["status"]).to eq("delivered")
      expect(notification["reference"]).to eq("your_reference_string")
    end
  end

  describe ".call" do
    let(:template_id) { EmailAlertAPI.config.notify.fetch(:template_id) }
    let(:arguments) do
      {
        address: "email@address.com",
        subject: "subject",
        body: "body",
        reference: "ref-123",
      }
    end

    it "calls the Notifications client" do
      client = instance_double("Notifications::Client")
      allow(Notifications::Client).to receive(:new).and_return(client)

      expect(client).to receive(:send_email)
        .with(
          email_address: "email@address.com",
          template_id: template_id,
          reference: "ref-123",
          personalisation: {
            subject: "subject",
            body: "body",
          },
        )

      described_class.call(arguments)
    end

    context "when it sends successfully" do
      before { stub_request(:post, /fake-notify/).to_return(body: {}.to_json) }

      it "returns a status of sending" do
        return_value = described_class.call(arguments)
        expect(return_value).to be(:sending)
      end
    end

    context "when an error occurs" do
      before do
        allow_any_instance_of(Notifications::Client).to receive(:send_email)
          .and_raise("Sending Failed")
      end

      it "returns a status of technical_failure" do
        return_value = described_class.call(arguments)
        expect(return_value).to be(:technical_failure)
      end

      it "notifies GovukError" do
        expect(GovukError).to receive(:notify)
        described_class.call(arguments)
      end
    end
  end
end
