namespace :notify_report do
  desc "Query the Notify API about a single email"
  task :get_email_status_from_notify, [:id] => :environment do |_t, args|
    notify_provider = NotifyProvider.new
    notify_provider.get_notify_email_status(args[:id])
  end
end
