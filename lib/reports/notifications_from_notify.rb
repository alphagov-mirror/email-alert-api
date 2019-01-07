module Reports
  class NotificationsFromNotify
    def initialize(config: EmailAlertAPI.config.notify)
      api_key = config.fetch(:api_key)
      base_url = config.fetch(:base_url)

      @client = Notifications::Client.new(api_key, base_url)
      @template_id = config.fetch(:template_id)
    end

    def self.call(*args)
      new.call(*args)
    end

    def call(reference)
      #reference is the DeliveryAttempt.id
      puts "Query Notify for emails with the reference #{reference}"

      response = @client.get_notifications(
        {
          template_type: "email",
          reference: reference
        }
      )

      # puts "Response =  #{response}"
      if response.is_a?(Notifications::Client::NotificationsCollection)
        count = response.collection.count

        response.collection.each do |notification|
          puts <<~TEXT
            -------------------------------------------
            Notification ID: #{notification.id}
            Status: #{notification.status}
            created_at: #{notification.created_at}
            sent_at: #{notification.sent_at}
            completed_at: #{notification.completed_at}
          TEXT
        end

      elsif response.is_a?(Notifications::Client::RequestError)
        puts "Query for #{reference} returns error code #{error.code}, #{error.message}"
      else
        puts "Reference not found"
      end
     end
  end

  private

    attr_reader :client, :template_id
end
