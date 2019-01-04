namespace :notify_report do
  # desc "Query the Notify API about a single email"
  # task :get_email_status_from_notify, [:id] => :environment do |_t, args|
  #   notify_provider = NotifyProvider.new
  #   notify_provider.get_notify_email_status(args[:id])
  # end

  desc "Query the Notify API for email(s) by reference"
  task :get_multiple_notifications_from_notify, [:reference] => :environment do |_t, args|
    notify_provider = NotifyProvider.new
    notify_provider.get_notify_multiple_email_status(args[:reference])
  end
end
