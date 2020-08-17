class DigestRunCompletionMarkerWorker
  include Sidekiq::Worker

  def perform(*_ignore)
    DigestRun.incomplete.each(&:check_if_completed)
  end
end
