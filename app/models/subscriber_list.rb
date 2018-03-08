class SubscriberList < ApplicationRecord
  include SymbolizeJSON

  self.include_root_in_json = true

  validate :tag_values_are_valid
  validate :link_values_are_valid

  validates :title, presence: true

  has_many :subscriptions
  has_many :subscribers, through: :subscriptions
  has_many :matched_content_changes

  def self.build_from(params:, gov_delivery_id:)
    new(
      title: params[:title],
      tags:  params[:tags],
      links: params[:links],
      document_type: params[:document_type],
      email_document_supertype: params[:email_document_supertype],
      government_document_supertype: params[:government_document_supertype],
      gov_delivery_id: gov_delivery_id,
    )
  end

  def subscription_url
    PublicUrlService.subscription_url(gov_delivery_id: gov_delivery_id)
  end

  def to_json(options = {})
    options[:except] ||= %i{signon_user_uid}
    options[:methods] ||= %i{subscription_url}
    super(options)
  end

  def is_travel_advice?
    self[:links].include?("countries")
  end

  def is_medical_safety_alert?
    self[:tags].fetch("format", []).include?("medical_safety_alert")
  end

private

  def tag_values_are_valid
    unless self[:tags].all? { |_, v| v.is_a?(Array) }
      self.errors.add(:tags, "All tag values must be sent as Arrays")
    end
  end

  def link_values_are_valid
    unless self[:links].all? { |_, v| v.is_a?(Array) }
      self.errors.add(:links, "All link values must be sent as Arrays")
    end
  end

  def gov_delivery_config
    EmailAlertAPI.config.gov_delivery
  end
end
