class ImmediateEmailGenerationService < ApplicationService
  BATCH_SIZE = 5000

  def initialize(content, **)
    @content = content
  end

  def call
    subscriber_batches.each do |batch|
      email_ids = batch.generate_emails
      email_ids.each do |id|
        SendEmailWorker.perform_async_in_queue(
          id,
          worker_metrics,
          queue: content.queue,
        )
      end
    end
  end

private

  attr_reader :content

  def subscriber_batches
    @subscriber_batches ||= begin
      scope = Subscription.for_content_change(content) if content.is_a?(ContentChange)
      scope = Subscription.for_message(content) if content.is_a?(Message)

      scope
        .active
        .immediately
        .dedup_by_subscriber
        .each_slice(BATCH_SIZE)
        .map do |subscription_ids|
          Batch.new(content, subscription_ids)
        end
    end
  end

  def worker_metrics
    @worker_metrics ||= case content
                        when ContentChange
                          { "content_change_created_at" => content.created_at.iso8601 }
                        else
                          {}
                        end
  end
end
