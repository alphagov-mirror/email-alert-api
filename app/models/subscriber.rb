class Subscriber < ApplicationRecord
  with_options allow_nil: true do
    validates :address, email_address: true
    validates :address, uniqueness: { case_sensitive: false }
  end

  validate :not_nullified_and_activated

  has_many :subscriptions
  has_many :active_subscriptions, -> { active }, class_name: "Subscription"
  has_many :ended_subscriptions, -> { ended }, class_name: "Subscription"
  has_many :subscriber_lists, through: :subscriptions
  has_many :digest_run_subscribers, dependent: :destroy
  has_many :digest_runs, through: :digest_run_subscribers

  scope :activated, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }
  scope :nullified, -> { where(address: nil) }
  scope :not_nullified, -> { where.not(address: nil) }

  def self.find_by_address(address)
    find_by("lower(address) = ?", address.downcase)
  end

  def self.find_by_address!(address)
    find_by!("lower(address) = ?", address.downcase)
  end

  def self.resilient_find_or_create(address, create_params = {})
    retries ||= 0
    # we run this in it's own transaction as we anticipate failure here and
    # want to isolate any failed transactions.
    transaction(requires_new: true) do
      subscriber = find_by_address(address)
      subscriber || create!({ address: address }.merge(create_params))
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # if we have concurrent requests trying to find or create the same
    # subscriber both can fail to find by address and then the both try
    # create the record. This retries the first time an
    # ActiveRecord::RecordNotUnique error is raised with the expectation
    # that this occurring more than once is a bigger problem.
    (retries += 1) == 1 ? retry : raise
  end

  def activated?
    deactivated_at.nil?
  end

  def activate!
    raise "Cannot activate if nullified." if nullified?
    raise "Already activated." if activated?

    update!(deactivated_at: nil)
  end

  def deactivated?
    deactivated_at.present?
  end

  def deactivate!(datetime: nil)
    raise "Already deactivated." if deactivated?

    update!(deactivated_at: datetime || Time.zone.now)
  end

  def nullified?
    address.nil?
  end

  def nullify!
    raise "Already nullified." if nullified?
    raise "Must be deactivated first." unless deactivated?

    update!(address: nil)
  end

  def as_json(options = {})
    options[:except] ||= %i[signon_user_uid]
    super(options)
  end

private

  def not_nullified_and_activated
    if nullified? && !deactivated?
      errors.add(:deactivated_at, "should be set to the deactivation date")
    end
  end
end
