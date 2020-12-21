RSpec.describe "Sending an email", type: :request do
  scenario do
    params = {
      body: "Description",
      subject: "Update from GOV.UK",
      address: "test@test.com",
    }

    post "/emails", params: params.to_json, headers: json_headers

    email_data = expect_an_email_was_sent(
      subject: "Update from GOV.UK",
      address: "test@test.com",
    )

    body = email_data.dig(:personalisation, :body)
    expect(body).to include("Description")
  end
end
