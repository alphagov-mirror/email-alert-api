RSpec.describe ContentChangeHandlerService do
  around(:example) do |example|
    Sidekiq::Testing.fake! do
      freeze_time { example.run }
    end
  end

  let(:params) do
    {
      subject: "This is a subject",
      tags: {
        topics: ["oil-and-gas/licensing"],
      },
      links: {
        organisations: %w[c380ea42-5d91-41cc-b3cd-0a4cfe439461],
        taxon_tree: %w[6416e4e0-c0c1-457a-8337-4bf8ed9d5f80],
      },
      content_id: "afe78383-6b27-45a4-92ae-a579e416373a",
      title: "Travel advice",
      change_note: "This is a change note",
      description: "This is a description",
      base_path: "/government/things",
      public_updated_at: Time.zone.now.to_s,
      email_document_supertype: "email document supertype",
      government_document_supertype: "government document supertype",
      document_type: "news_article",
      publishing_app: "publishing app",
    }
  end

  let(:govuk_request_id) { SecureRandom.uuid }

  let!(:subscriber_list) do
    create(:subscriber_list, tags: { topics: { any: ["oil-and-gas/licensing"] } })
  end

  let(:document_type_hash) do
    {
      navigation_document_supertype: "other",
      content_purpose_document_supertype: "news",
      user_journey_document_supertype: "thing",
      search_user_need_document_supertype: "government",
      email_document_supertype: "other",
      government_document_supertype: "other",
      content_purpose_subgroup: "news",
      content_purpose_supergroup: "news_and_communications",
      content_store_document_type: "news_article",
    }
  end

  describe ".call" do
    it "creates a ContentChange" do
      expect { described_class.call(params: params, govuk_request_id: govuk_request_id) }
        .to change { ContentChange.count }.by(1)
    end

    let(:content_change) { create(:content_change) }

    it "adds GovukDocumentTypes to the content_change tags" do
      described_class.call(params: params, govuk_request_id: govuk_request_id)

      expect(ContentChange.last).to have_attributes(
        title: "Travel advice",
        base_path: "/government/things",
        change_note: "This is a change note",
        description: "This is a description",
        links: hash_including(
          organisations: %w[c380ea42-5d91-41cc-b3cd-0a4cfe439461],
          content_store_document_type: "news_article",
          taxon_tree: %w[6416e4e0-c0c1-457a-8337-4bf8ed9d5f80],
        ),
        tags: hash_including(
          topics: ["oil-and-gas/licensing"],
          content_store_document_type: "news_article",
        ),
        email_document_supertype: "email document supertype",
        government_document_supertype: "government document supertype",
        govuk_request_id: govuk_request_id,
        document_type: "news_article",
        publishing_app: "publishing app",
        processed_at: nil,
        priority: "normal",
        signon_user_uid: nil,
        footnote: "",
      )
    end

    it "adds GovukDocumentTypes to the content_change links" do
      described_class.call(params: params, govuk_request_id: govuk_request_id)
      expect(ContentChange.last.links).to include(document_type_hash)
    end

    it "adds GovukDocumentTypes to the content_change tags" do
      described_class.call(params: params, govuk_request_id: govuk_request_id)
      expect(ContentChange.last.tags).to include(document_type_hash)
    end

    it "enqueues the content change to be processed by the subscription content worker" do
      allow(ContentChange).to receive(:create!).and_return(content_change)

      expect(ProcessContentChangeWorker)
        .to receive(:perform_async)
        .with(content_change.id)

      described_class.call(params: params, govuk_request_id: govuk_request_id)
    end

    it "Raises errors if the ContentChange is invalid" do
      allow(ContentChange).to receive(:create!).and_raise(
        ActiveRecord::RecordInvalid,
      )

      expect { described_class.call(params: params, govuk_request_id: govuk_request_id) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
