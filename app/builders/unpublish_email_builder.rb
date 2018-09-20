class UnpublishEmailBuilder
  def self.call(*args)
    new.call(*args)
  end

  def call(emails, template)
    Email.import!(email_records(emails, template)).ids
  end

private

  def email_records(email_parameters, template)
    email_parameters.map do |email|
      {
        address: email.address,
        subject: "GOV.UK update – #{email.subject}",
        body: ERB.new(template).result(email.fetch_binding),
        subscriber_id: email.subscriber_id
      }
    end
  end
end