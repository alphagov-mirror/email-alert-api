RSpec.describe "Subscribers auth token", type: :request do
  before { login_with_internal_app }

  describe "creating an auth token" do
    let(:path) { "/subscribers/auth-token" }
    let(:address) { "test@example.com" }
    let(:params) do
      {
        address: address,
        destination: "/test",
      }
    end

    it "returns 201" do
      post path, params: params
      expect(response.status).to eq(201)
    end

    it "sends an email" do
      expect(DeliveryRequestWorker).to receive(:perform_async_in_queue)
      post path, params: params
    end

    context "when we have an existing user" do
      let!(:subscriber) { create(:subscriber, address: address) }

      it "returns subscriber details" do
        post path, params: params
        expect(data[:subscriber][:id]).to eq(subscriber.id)
      end
    end

    context "when we user we didn't previously know" do
      it "creates the new user" do
        expect { post path, params: params }
          .to change { Subscriber.count }
          .by(1)
      end
    end

    context "when we have a deactivated user" do
      let!(:subscriber) { create(:subscriber, :deactivated, address: address) }

      it "re-activates the subscriber" do
        expect { post path, params: params }
          .to change { subscriber.reload.activated? }
          .from(false)
          .to(true)
      end
    end

    context "when we're provided with a bad email address" do
      it "returns a 422" do
        pending("validation")
        post path, params: params
        expect(response.status).to eq(422)
      end
    end
  end
end
