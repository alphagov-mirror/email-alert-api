RSpec.describe "Creating a subscription", type: :request do
  context "with authentication and authorisation" do
    before do
      login_with_internal_app
    end

    context "with a subscriber_list" do
      let(:subscriber_list) { create(:subscriber_list) }

      it "returns a 201" do
        params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id)
        post "/subscriptions", params: params, headers: json_headers

        expect(response.status).to eq(201)
      end

      it "sets the source to a user signup" do
        params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id)
        post "/subscriptions", params: params, headers: json_headers

        expect(Subscription.first.source_user_signed_up?).to be true
      end

      context "with a frequency setting" do
        it "returns a 201 and sets the frequency" do
          params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id, frequency: "daily")
          post "/subscriptions", params: params, headers: json_headers

          expect(response.status).to eq(201)

          expect(Subscription.first.daily?).to be_truthy
          expect(Subscription.first.source_user_signed_up?).to be true
        end

        context "with an existing subscription" do
          it "updates the frequency" do
            params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id, frequency: "daily")
            post "/subscriptions", params: params, headers: json_headers

            expect(response.status).to eq(201)

            params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id, frequency: "weekly")
            post "/subscriptions", params: params, headers: json_headers

            expect(response.status).to eq(200)

            old_subscription = Subscription.order(:created_at).first
            expect(old_subscription.weekly?).to be false
            expect(old_subscription.ended?).to be true
            expect(old_subscription.ended_frequency_changed?).to be true

            new_subscription = Subscription.order(:created_at).last
            expect(new_subscription.weekly?).to be true
            expect(new_subscription.source_frequency_changed?).to be true

            expect(Subscription.active.count).to eq(1)
          end
        end

        context "with an existing subscription but a different case" do
          it "returns a successful response" do
            params = JSON.dump(address: "Test@example.com", subscriber_list_id: subscriber_list.id, frequency: "daily")
            post "/subscriptions", params: params, headers: json_headers

            expect(response.status).to eq(201)

            params = JSON.dump(address: "test@example.com", subscriber_list_id: subscriber_list.id, frequency: "weekly")
            post "/subscriptions", params: params, headers: json_headers

            expect(response.status).to eq(200)
          end
        end

        context "with a notify email address" do
          it "returns a 201 but doesn't create a subscriber or subscription" do
            params = JSON.dump(address: "simulate-delivered@notifications.service.gov.uk", subscriber_list_id: subscriber_list.id, frequency: "daily")
            expect { post "/subscriptions", params: params, headers: json_headers }.to_not change(Subscriber, :count)

            expect(response.status).to eq(201)
          end
        end

        context "with a deactivated subscriber" do
          before do
            create(:subscriber, :deactivated, address: "deactivated@example.com")
          end

          it "activates the subscriber" do
            params = JSON.dump(address: "deactivated@example.com", subscriber_list_id: subscriber_list.id)
            post "/subscriptions", params: params, headers: json_headers

            expect(Subscriber.first.deactivated?).to be false
            expect(Subscriber.first.activated?).to be true
          end
        end
      end
    end
  end

  context "without authentication" do
    it "returns a 401" do
      without_login do
        post "/subscriptions", params: {}, headers: {}
        expect(response.status).to eq(401)
      end
    end
  end

  context "without authorisation" do
    it "returns a 403" do
      login_with_signin
      post "/subscriptions", params: {}, headers: {}
      expect(response.status).to eq(403)
    end
  end
end
