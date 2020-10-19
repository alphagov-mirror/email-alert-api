# Decision Record: Email Sending and Delivery Responsibilities

## Introduction

The [initial Email Alert API Notify integration][adr-1] was designed to
monitor whether Notify was delivering emails to recipients and to have
automatic retry mechanisms when there were problems with this delivery.

In September 2020, we re-evaluated the need for this level of monitoring and
concluded that this was unnecessary as it duplicated functionality that
Notify provided. We chose to simplify the system and re-define the
responsibilities of email sending and delivery. We decided
that Email Alert API's responsibility in sending email was ensuring a request
was sent to Notify and that the onward responsibility of email delivery
was a concern that belonged to Notify.

[adr-1]: adr-001-notify-integration.md

## Specifics

Email, as an asynchronous communication medium, inherently has two boolean
scenarios that need to be true for an email to be received. An email has to be
_sent_ to a mail server and the mail server then needs to _deliver_ the email to the
recipient's mail server. Resolving whether an email is sent is a rather simple
and question that can be resolved synchronously - "did the mail server accept the
email?" - however, determining whether an email is received is more complex
and it can be a drawn out process as mail servers may retry sending over a period
of time when encountering failures. Typically, in the medium of email, clients
only consider the first scenario in reporting an email's status, this is the
point an email becomes sent. Whereas the latter scenario isn't typically
reflected in email clients, it is normal to assume the email was received
successfully unless later you receive an email indicating a bounce has occurred.

With regards to Email Alert API we consider the process of sending an email
to be a successful HTTP request to Notify. We then consider the
[callback][notify-callback] Notify provides as the mechanism to learn if
an email was delivered.

We reflected that Email Alert API had diverged from the common pattern of email
clients by conflating the sending and delivery of email. This resulted
in the sending of email to be somewhat pessimistic - we considered an email to
only be sent when it was confirmed to be delivered - and to be
somewhat confusing, with terminology about sending emails mixed with
terminology about delivering email.

To resolve these concerns we have switched to considering an email to
be _sent_ when the request to Notify is successful, which will end the period
where an email is in a transitory `pending` status. We will consider it the
responsibility of Notify to manage and monitor the delivery of an email,
which is already part of the Notify service.

[notify-callback]: https://docs.notifications.service.gov.uk/ruby.html#delivery-receipts

### Consequences

#### Emails will leave their `pending` state when sent to Notify

Email Alert API would consider an email to be in a `pending` status until
receiving a Notify callback that confirmed the email was delivered. When in a
`pending` state an email could not be [archived or deleted][] from the system.
Instead, once a successful request is made to Notify, we will consider the
email to be no longer pending and be in a final `sent` status.

This reflects a more optimistic outlook towards email sending. Data suggests
that it is very rare that an email fails to be delivered (On Friday 16th
October 5,338,956 were delivered, against 21,966 failures, providing a 0.4%
failure rate). By making the state of an email dependent on a callback we were
leaving a problem that any lost or missed callbacks left the system in an
[inconsistent state][archive-pr].

This will mean that emails are eligible for archiving and deletion sooner,
due to the lack of wait for a callback. It will also render some of the
delivery focused terminology (`DeliveryRequest`, `DeliveryAttempt`) obsolete
given the system is now focused on email sending rather than email delivery,
so these will be renamed.

[archived or deleted]: https://github.com/alphagov/email-alert-api/blob/59fc71a58317ef2998f2c0ef102020da3ca9df96/app/models/email.rb#L8-L16
[archive-pr]: https://github.com/alphagov/email-alert-api/pull/1411

#### We will no longer retry sending emails ourselves

Notify, via Amazon SES, will automatically [retry][ses-bounce] the sending of
emails that fail for transitory reasons (such as the recipient's mail server
being full or offline). If it doesn't succeed in a reasonable period
of time Notify will inform us by telling us an email has experienced a
["temporary-failure"][temporary-failure-status].

Email Alert API will no longer have its own retry mechanism that retries
email sending beyond what Notify does. This resolves an aspect of duplicated
functionality between the two systems and an aspect of ambiguity as to
how long Email Alert API should retry the sending of an email for.
With this removed there will no longer be multiple attempts to send an email
with Notify, which allows us to delete the `DeliveryAttempt` model - given its
purpose is to disambiguate between attempts.

[ses-bounce]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-concepts-deliverability.html#send-email-concepts-deliverability-bounce
[temporary-failure-status]: https://docs.notifications.service.gov.uk/ruby.html#status-email

#### We will no longer record delivery data on an email

A question we pondered with these changes was "what should do with the data
we receive from Notify about the delivery of emails?". Now that this no longer
plays a role in the state modelling of an email it risked confusion
to include it in an email's status (it conflated what a failure to send
an email meant - was this failure to _send_ or failure to _deliver_?).

We decided that we did not need to store delivery success or failure in the
database with the email. This is because there is not currently
a known use of this data and, since the email table only has a 7-day retention
period, can be added later to meet any later needs that are identified. The
data will remain available via the Notify UI for debugging whether emails
were delivered.

We will [continue to act on "permanent-failure"][permanent-failure]
notifications and remove subscriptions for non-operational email addresses -
this can be done without storing additional data with the email. We will also
continue to store aggregate data on delivery which will continue to power
dashboards.

[permanent-failure]: https://github.com/alphagov/email-alert-api/blob/59fc71a58317ef2998f2c0ef102020da3ca9df96/app/services/status_update_service.rb#L17-L19
