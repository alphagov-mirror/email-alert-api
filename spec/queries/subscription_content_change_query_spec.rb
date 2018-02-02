RSpec.describe SubscriptionContentChangeQuery do
  let(:subscriber) do
    create(:subscriber)
  end

  let(:ends_at) { Time.parse("2017-01-02 08:00") }

  let(:digest_run) do
    create(:digest_run, :daily, date: ends_at)
  end

  let(:starts_at) { digest_run.starts_at }

  subject { described_class.call(subscriber: subscriber, digest_run: digest_run) }

  context "with one subscription" do
    let(:subscriber_list) do
      create(:subscriber_list, tags: { topics: ["oil-and-gas/licensing"] })
    end

    let!(:subscription) do
      create(:subscription, subscriber_list: subscriber_list, subscriber: subscriber)
    end

    def create_and_match_content_change(created_at: starts_at, title: nil)
      content_change = create(
        :content_change,
        tags: { topics: ["oil-and-gas/licensing"] },
        created_at: created_at,
      )
      content_change.update!(title: title) if title
      create(
        :matched_content_change,
        content_change: content_change,
        subscriber_list: subscriber_list,
      )
    end

    describe ".call" do
      context "with a matched content change" do
        before do
          create_and_match_content_change
        end

        it "returns one result" do
          expect(subject.first.content_changes.count).to eq(1)
        end
      end

      context "with two matched content changes" do
        before do
          create_and_match_content_change(title: "Z")
          create_and_match_content_change(title: "A")
        end

        it "returns two results correctly ordered" do
          expect(subject.first.content_changes.count).to eq(2)
          expect(subject.first.content_changes.first.title).to eq("A")
          expect(subject.first.content_changes.second.title).to eq("Z")
        end
      end

      context "with a matched content change that's out of date" do
        before do
          create_and_match_content_change(created_at: ends_at)
        end

        it "returns no results" do
          expect(subject.count).to eq(0)
        end
      end

      context "with no matched content changes" do
        before do
          create(:content_change)
        end

        it "returns no results" do
          expect(subject.count).to eq(0)
        end
      end
    end
  end

  context "with two subscriptions" do
    let(:subscriber_list_1) do
      create(:subscriber_list, title: "list-1", tags: { topics: ["oil-and-gas/licensing"] })
    end

    let(:subscriber_list_2) do
      create(:subscriber_list, title: "list-2", tags: { topics: ["oil-and-gas/drilling"] })
    end

    let!(:subscription_2) do
      create(:subscription, id: 2, subscriber_list: subscriber_list_2, subscriber: subscriber)
    end

    let!(:subscription_1) do
      create(:subscription, id: 1, subscriber_list: subscriber_list_1, subscriber: subscriber)
    end

    let(:content_change_1) do
      create(
        :content_change,
        id: 1,
        tags: { topics: ["oil-and-gas/licensing"] },
        created_at: starts_at,
      )
    end

    let(:content_change_2) do
      create(
        :content_change,
        id: 2,
        tags: { topics: ["oil-and-gas/drilling"] },
        created_at: starts_at,
      )
    end

    before do
      create(
        :matched_content_change,
        content_change: content_change_1,
        subscriber_list: subscriber_list_1,
      )

      create(
        :matched_content_change,
        content_change: content_change_2,
        subscriber_list: subscriber_list_2,
      )
    end

    it "returns correctly ordered" do
      expect(subject.first.subscription_id).to eq(1)
      expect(subject.first.subscriber_list_title).to eq("list-1")
      expect(subject.first.content_changes.first.id).to eq(1)

      expect(subject.second.subscription_id).to eq(2)
      expect(subject.second.subscriber_list_title).to eq("list-2")
      expect(subject.second.content_changes.first.id).to eq(2)
    end
  end
end