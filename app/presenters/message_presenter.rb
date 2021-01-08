class MessagePresenter < ApplicationPresenter
  def initialize(message, _subscription = nil)
    @message = message
  end

  def call
    message.body
  end

private

  attr_reader :message
end
