class ContentChangeHandlerService
  def initialize(params:, govuk_request_id:, user: nil)
    @params = params
    @govuk_request_id = govuk_request_id
    @user = user
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    ActiveRecord::Base.transaction do
      content_change = ContentChange.create!(content_change_params)
      MetricsService.content_change_created
      MatchedContentChangeGenerationService.call(content_change: content_change)
      ProcessContentChangeAndGenerateEmailsWorker.perform_async(content_change.id)
    end
  end

  private_class_method :new

private

  attr_reader :params, :govuk_request_id, :user

  def content_change_params
    {
      content_id: params[:content_id],
      title: params[:title],
      change_note: params[:change_note],
      description: params[:description],
      base_path: params[:base_path],
      links: with_supertypes(params.fetch(:links, {})),
      tags: with_supertypes(params.fetch(:tags, {})),
      public_updated_at: params[:public_updated_at],
      email_document_supertype: params[:email_document_supertype],
      government_document_supertype: params[:government_document_supertype],
      govuk_request_id: govuk_request_id,
      document_type: params[:document_type],
      publishing_app: params[:publishing_app],
      priority: params.fetch(:priority, "normal").to_sym,
      signon_user_uid: user&.uid,
      footnote: params.fetch(:footnote, ""),
    }
  end

  def with_supertypes(hash)
    supertypes = GovukDocumentTypes.supertypes(document_type: params[:document_type])
    content_store_document_type = { content_store_document_type: params[:document_type] }
    supertypes.merge(hash).merge(content_store_document_type)
  end
end
