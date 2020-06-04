require "rails_helper"

RSpec.describe "bulk" do
  describe "email" do
    before do
      Rake::Task["bulk:email"].reenable
      allow(ENV).to receive(:fetch).with("SUBJECT").and_return("subject")
      allow(ENV).to receive(:fetch).with("BODY").and_return("body")
    end

    it "sends emails to a subscription list" do
      subscriber_list = create(:subscriber_list)
      expect(BulkEmailSenderService).to receive(:call).with(
        bulk_email_builder: BulkEmailBuilder.call(
          subject: "subject",
          body: "body",
          subscriber_lists: subscriber_list,
        ),
      )

      Rake::Task["bulk:email"].invoke(subscriber_list.id)
    end
  end
end
