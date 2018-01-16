class NotificationHandlerService
  attr_reader :params, :user
  def initialize(params:, user: nil)
    @params = params
    @user = user
  end

  def self.call(*args)
    new(*args).call
  end

  def call
    begin
      content_change = ContentChange.create!(content_change_params)
      MetricsService.content_change_created
      SubscriptionContentWorker.perform_async(content_change.id)
    rescue StandardError => ex
      Raven.capture_exception(ex, tags: { version: 2 })
    end
  end

private

  def content_change_params
    {
      content_id: params[:content_id],
      title: params[:title],
      change_note: params[:change_note],
      description: params[:description],
      base_path: params[:base_path],
      links: params[:links],
      tags: params[:tags],
      public_updated_at: Time.parse(params[:public_updated_at]),
      email_document_supertype: params[:email_document_supertype],
      government_document_supertype: params[:government_document_supertype],
      govuk_request_id: params[:govuk_request_id],
      document_type: params[:document_type],
      publishing_app: params[:publishing_app],
      priority: params.fetch(:priority, "low").to_sym,
      signon_user_uid: user&.uid,
    }
  end
end
