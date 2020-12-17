class DigestEmailBuilder < ApplicationBuilder
  def initialize(address:, digest_item:, digest_run:, subscriber_id:)
    @address = address
    @digest_item = digest_item
    @digest_run = digest_run
    @subscriber_id = subscriber_id
  end

  def call
    Email.create!(
      address: address,
      subject: I18n.t!(
        "emails.digests.#{digest_run.range}.subject",
        title: digest_item.subscriber_list_title,
      ),
      body: body,
      subscriber_id: subscriber_id,
    )
  end

private

  attr_reader :address, :digest_item, :digest_run, :subscriber_id

  def body
    <<~BODY
      Update from GOV.UK for:

      #{title_and_optional_description}

      ---

      # #{I18n.t("emails.digests.#{digest_run.range}.heading")}

      #{presented_results}

      ---

      # Why am I getting this email?

      #{I18n.t("emails.digests.#{digest_run.range}.footer_explanation")}

      #{digest_item.subscriber_list_title}

      [Unsubscribe](#{unsubscribe_url})

      [#{I18n.t!('emails.digests.footer_manage')}](#{PublicUrls.authenticate_url(address: address)})
    BODY
  end

  def presented_results
    changes = digest_item.content.map do |item|
      presenter = "#{item.class.name}Presenter".constantize
      presenter.call(item, frequency: digest_run.range)
    end

    changes.join("\n---\n\n").strip
  end

  def title_and_optional_description
    result = "# " + digest_item.subscriber_list_title

    if digest_item.subscriber_list_description.present?
      result += "\n\n" + digest_item.subscriber_list_description
    end

    result
  end

  def unsubscribe_url
    PublicUrls.unsubscribe(
      subscription_id: digest_item.subscription_id,
      subscriber_id: subscriber_id,
    )
  end
end
