class BulkEmailBodyPresenter < ApplicationPresenter
  def initialize(body, subscriber_list)
    @body = body
    @subscriber_list = subscriber_list
  end

  def call
    body.gsub("%LISTURL%", list_url)
  end

private

  attr_reader :body, :subscriber_list

  def list_url
    utm_source = subscriber_list.slug
    utm_medium = "email"
    utm_campaign = "govuk-notifications-bulk"
    base_path = "#{subscriber_list.url}?utm_source=#{utm_source}&utm_medium=#{utm_medium}&utm_campaign=#{utm_campaign}"
    PublicUrls.url_for(base_path: base_path)
  end
end
