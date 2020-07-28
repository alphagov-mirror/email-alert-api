class SubscriptionsController < ApplicationController
  def create
    return render json: { id: 0 }, status: :created if smoke_test_address?

    subscription = send_email = status = nil

    Subscription.transaction do
      if (subscriber_was_deactivated = subscriber.deactivated?)
        subscriber.activate!
      end

      existing_subscription = Subscription.active.lock.find_by(
        subscriber: subscriber,
        subscriber_list: subscriber_list,
      )

      create_new_subscription = existing_subscription.nil? ||
        (frequency.to_s != existing_subscription.frequency.to_s)

      if create_new_subscription
        existing_subscription&.end(reason: :frequency_changed)
        new_subscription = Subscription.create!(
          subscriber: subscriber,
          subscriber_list: subscriber_list,
          frequency: frequency,
          signon_user_uid: current_user.uid,
          source: existing_subscription ? :frequency_changed : :user_signed_up,
        )
      end

      subscription = new_subscription || existing_subscription
      send_email = create_new_subscription || subscriber_was_deactivated
      status = existing_subscription.nil? ? :created : :ok
    end
    send_subscription_confirmation_email(subscription) if send_email
    render json: { id: subscription.id }, status: status
  end

  def show
    subscription = Subscription.find(subscription_params.require(:id))
    render json: { subscription: subscription }
  end

  def update
    subscription = nil

    Subscription.transaction do
      existing_subscription = Subscription.active.lock.find(
        subscription_params.require(:id),
      )

      existing_subscription.end(reason: :frequency_changed)

      begin
        subscription = Subscription.create!(
          subscriber: existing_subscription.subscriber,
          subscriber_list: existing_subscription.subscriber_list,
          frequency: frequency,
          signon_user_uid: current_user.uid,
          source: :frequency_changed,
        )
      rescue ArgumentError
        # This happens if a frequency is provided that isn't included
        # in the enum which is in the Subscription model
        raise ActiveRecord::RecordInvalid
      end
    end

    render json: { subscription: subscription }
  end

  def latest_matching
    subscription = Subscription.find(subscription_params.require(:id))
    render json: { subscription: FindLatestMatchingSubscription.call(subscription) }, status: :ok
  end

private

  def smoke_test_address?
    address.end_with?("@notifications.service.gov.uk")
  end

  def subscriber
    @subscriber ||= Subscriber.resilient_find_or_create(
      address,
      signon_user_uid: current_user.uid,
    )
  end

  def address
    subscription_params.require(:address)
  end

  def subscriber_list
    @subscriber_list ||= SubscriberList.find(subscriber_list_id)
  end

  def subscriber_list_id
    subscription_params[:subscribable_id] || subscription_params.require(:subscriber_list_id)
  end

  def frequency
    subscription_params.fetch(:frequency, "immediately").to_sym
  end

  def subscription_params
    params.permit(:id, :address, :subscribable_id, :subscriber_list_id, :frequency)
  end

  def send_subscription_confirmation_email(subscription)
    email = SubscriptionConfirmationEmailBuilder.call(subscription: subscription)
    DeliveryRequestWorker.perform_async_in_queue(email.id, queue: :delivery_transactional)
  end
end
