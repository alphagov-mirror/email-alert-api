RSpec.describe "Delivering an email successfully via Notify", type: :request do
  before do
    stub_notify
  end

  scenario "sending an email and receiving a 'delivered' status update" do
    login_with(%w[internal_app status_updates])

    subscriber_list_id = create_subscriber_list
    subscribe_to_subscriber_list(subscriber_list_id)
    create_content_change
    email_data = expect_an_email_was_sent

    reference = email_data.fetch(:reference)

    send_status_update(reference, "delivered", expected_status: 204)
    send_status_update("missing", "delivered", expected_status: 404)
    send_status_update(nil,       "delivered", expected_status: 400)
  end
end
