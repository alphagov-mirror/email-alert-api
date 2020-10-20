# Decision Record: Email Delivery Responsibilities

## Introduction

Email, as an asynchronous communication medium, inherently has two boolean
scenarios that need to be true for an email to be received. An email has to be
_sent_ to a mail server and the mail server then needs to _deliver_ the email to the
recipient's mail server. Resolving whether an email is sent is a rather simple
and question that can be resolved synchronously - "did the mail server accept the
email?" - however, determining whether an email is received is more complex
and it can be a drawn out process as mail servers may retry delivery over a
period of time when encountering failures. Typically, in the medium of email,
clients only consider the first scenario in reporting an email's status, this
is the point an email becomes sent. Whereas the latter scenario isn't typically
reflected in email clients, it is normal to assume the email was received
successfully unless later you receive an email indicating a bounce has occurred.

The [initial Email Alert API Notify integration][adr-1] was designed to
consider both the sending and delivering of email. It had systems to monitor
whether Notify had managed to deliver an email to a recipient and an automatic
retry mechanism for when Notify had problems delivering an email.

In September 2020, we re-evaluated the need for this level of functionality and
concluded that this was unnecessary as it duplicated features that
Notify provided. We chose to simplify the system and re-define the
responsibilities of email delivery. We decided that Email Alert API
had a responsibility to send email, but does not have a responsibility to
deliver it. That is the responsibility of Notify.

[adr-1]: adr-001-notify-integration.md

## Specifics

With regards to Email Alert API we consider the process of sending an email
to be a successful HTTP request to Notify and consider this an equivalent of
the process a mail client has in speaking to an [SMTP][] server. We then
consider the [callback][notify-callback] Notify provides as the mechanism to
learn if an email was delivered or not.

We reflected that Email Alert API had diverged from the common pattern of email
clients by conflating the sending and delivery of email. This resulted
in the modelling of email to be somewhat pessimistic - we considered an email to
only be [sent][sent-status] when it was confirmed to be delivered - and to be
somewhat confusing, with terminology about sending emails mixed with
terminology about delivery.

To resolve these concerns we have [switched][switched-to-sent-success] to
considering an email to be _sent_ when the request to Notify is successful,
which will end the period where an email is in a transitory `pending` status
that could mean anything from not sent, to delivered but the callback got lost.
We consider it the responsibility of Notify to manage and monitor the
delivery of an email, which is already part of the Notify service.

[SMTP]: https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
[notify-callback]: https://docs.notifications.service.gov.uk/ruby.html#delivery-receipts
[sent-status]: https://github.com/alphagov/email-alert-api/blob/956fc819f9396264083591e8accc3d4b4791fb4e/app/services/update_email_status_service.rb#L60
[switched-to-sent-success]: https://github.com/alphagov/email-alert-api/commit/c457f62c3b6f1eaadf47e6596223cc0fdcffa853

### Consequences

#### Emails leave their `pending` state when sent to Notify

Email Alert API would consider a sent email to be in a `pending` status until
receiving a Notify callback that confirmed the email was delivered. When in a
`pending` state an email could not be [archived or deleted][]. We have
replaced this approach with one where an email is marked as sent
once a successful request is made to Notify.

This reflects a more optimistic outlook towards email sending. Data suggests
that it is very rare that an email fails to be delivered (On Friday 16th
October 5,338,956 were delivered, against 21,966 failures, providing a 0.4%
failure rate). By making the state of an email dependent on a callback we were
leaving a problem that any lost or missed callbacks left the system in an
[inconsistent state][archive-pr].

This means that emails are eligible for archiving and deletion sooner,
due to the lack of wait for a callback. It also renders some of the
delivery focused terminology (`DeliveryRequest`, `DeliveryAttempt`) obsolete
given the system is now focused on email sending rather than email delivery,
these have been [renamed][renamed-delivery].

[archived or deleted]: https://github.com/alphagov/email-alert-api/blob/59fc71a58317ef2998f2c0ef102020da3ca9df96/app/models/email.rb#L8-L16
[archive-pr]: https://github.com/alphagov/email-alert-api/pull/1411
[renamed-delivery]: https://github.com/alphagov/email-alert-api/commit/ccf86a0267c0b2c0989235cd1e2eff7bcca31ecb

#### We no longer retry delivering emails ourselves

Notify, via Amazon SES, will automatically [retry][ses-bounce] the delivery of
emails that fail for transitory reasons (such as the recipient's mail server
being full or offline). If it doesn't succeed in a reasonable period
of time Notify will inform us by telling us an email has experienced a
["temporary-failure"][temporary-failure-status].

Email Alert API [no longer][no-retries-commit] has its own retry
mechanism to re-attempt emails that have failed to be delivered. This
resolves an aspect of duplicated functionality between the two systems and
an area of ambiguity as to how long Email Alert API should retry for. With
this removed there are no longer attempts to resend an email should the
first delivery fail, this allowed us to [delete the
`DeliveryAttempt` model][delete-delivery-attempt] as the purpose of this was
to disambiguate between different Notify requests.

[ses-bounce]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-concepts-deliverability.html#send-email-concepts-deliverability-bounce
[temporary-failure-status]: https://docs.notifications.service.gov.uk/ruby.html#status-email
[no-retries-commit]: https://github.com/alphagov/email-alert-api/commit/df9ad09fab5dabde5fac92ae76d155d00eea192b
[delete-delivery-attempt]: https://github.com/alphagov/email-alert-api/pull/1438

#### We no longer record delivery data with an email

A question we pondered with these changes was "what should do with the data
we receive from Notify about the delivery of emails?". Now that this no longer
plays a role in the state modelling of an email it risked confusion
to include it in an email's status (it conflated what a failure to send
an email meant - was this failure to _send_ or failure to _deliver_?).

We decided that we did not need to store delivery success or failure in the
database with the email. This is because there is not currently
a known use of this data and, since the email table only has a 7-day retention
period, can be added later to meet any later needs that are identified. The
data remains available via the Notify UI for debugging whether emails
were delivered.

We [continue to act on "permanent-failure"][permanent-failure]
notifications and remove subscriptions for non-operational email addresses -
this can be done without storing additional data with the email. We also
continue to store aggregate metrics about delivery which power dashboards.

[permanent-failure]: https://github.com/alphagov/email-alert-api/blob/59fc71a58317ef2998f2c0ef102020da3ca9df96/app/services/status_update_service.rb#L17-L19
