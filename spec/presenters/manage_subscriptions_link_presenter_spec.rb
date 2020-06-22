RSpec.describe ManageSubscriptionsLinkPresenter do
  describe ".call" do
    it "returns a manage subscriptions link" do
      expected = "[View, unsubscribe or change the frequency of your subscriptions](http://www.dev.gov.uk/email/manage/authenticate?address=test-email%40test.com)"
      expect(described_class.call("test-email@test.com")).to eq(expected)
    end
  end
end
