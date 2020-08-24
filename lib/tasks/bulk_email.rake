namespace :bulk_email do
  desc "Send a bulk email to many subscriber lists"
  task :for_lists, [] => :environment do |_t, args|
    email_ids = BulkSubscriberListEmailBuilder.call(
      subject: ENV.fetch("SUBJECT"),
      body: ENV.fetch("BODY"),
      subscriber_lists: SubscriberList.where(id: args.extras),
    )

    email_ids.each do |id|
      DeliveryRequestWorker.perform_async_in_queue(id, queue: :delivery_immediate)
    end
  end

  desc "Email all subscribers of the Brexit checker"
  task :brexit_subscribers, [:dry_run] => :environment do |_t, args|
    brexit_list_ids = SubscriberList.where("subscriber_lists.tags->>'brexit_checklist_criteria' IS NOT NULL").pluck(:id)
    email_ids =
      brexit_list_ids.map do |id|
        BulkSubscriberListEmailBuilder.call(
          subject: ENV.fetch("SUBJECT"),
          body: ENV.fetch("BODY"),
          subscriber_lists: SubscriberList.where(id: id),
        )
      end
    if args.dry_run == "not_dry_run"
      email_ids.flatten.each do |id|
        DeliveryRequestWorker.perform_async_in_queue(id, queue: :delivery_immediate)
      end
    else
      print "This task is in dry run mode. "
      print "It would have queued #{email_ids.flatten.count} emails for delivery"
    end
  end
end
