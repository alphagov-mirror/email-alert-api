class SubscribersAuthTokenController < ApplicationController
  before_action :validate_params

  def auth_token
    subscriber = find_subscriber(expected_params.require(:address))
    token = generate_token(subscriber)
    email = build_email(subscriber, token)

    DeliveryRequestWorker
      .perform_async_in_queue(email.id, queue: :delivery_transactional)

    render json: { subscriber: subscriber }, status: :created
  end

private

  def find_subscriber(address)
    Subscriber.find_by_address!(address).tap do |subscriber|
      subscriber.activate if subscriber.deactivated?
    end
  end

  def generate_token(subscriber)
    AuthTokenGeneratorService.call(
      "subscriber_id" => subscriber.id,
      "redirect" => expected_params[:redirect],
    )
  end

  def build_email(subscriber, token)
    SubscriberAuthEmailBuilder.call(
      subscriber: subscriber,
      destination: expected_params.require(:destination),
      token: token,
    )
  end

  def expected_params
    params.permit(:address, :destination, :redirect)
  end

  def validate_params
    ParamsValidator.new(expected_params).validate!
  end

  class ParamsValidator < OpenStruct
    include ActiveModel::Validations

    validates :address, presence: true
    validates :address, email_address: true, allow_blank: true

    validates :destination, presence: true
    validates :destination, root_relative_url: true, allow_blank: true
    validates :redirect, root_relative_url: true, allow_blank: true
  end
end
