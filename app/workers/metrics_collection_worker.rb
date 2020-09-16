class MetricsCollectionWorker
  include Sidekiq::Worker

  def perform
    MetricsCollectionWorker::ContentChangeExporter.call
    MetricsCollectionWorker::DigestRunExporter.call
    MetricsCollectionWorker::MessageExporter.call
  end
end
