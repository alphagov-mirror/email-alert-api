# Support tasks

Users can manage email subscribers via the [administration interface on GOV.UK][email-manage].
Support tickets coming through to 2ndline where the user is unaware of this,
or needs guidance, can be assigned to "2nd Line--User Support Escalation".

> **Note**
>
> This applies only to emails sent by GOV.UK.
> [Drug safety updates][drug-updates] are sent manually by MHRA, who manage
> their own service using Govdelivery. We do not have access to this.

If it is not possible for changes to be managed by the user, it is
possible for changes to be made manually. The following rake tasks
should be run using the Jenkins `Run rake task` job for ease-of-use:

[email-manage]: https://www.gov.uk/email/manage
[drug-updates]: https://www.gov.uk/drug-safety-update

## Change a subscriber's email address

This task changes a subscriber's email address.

```bash
$ bundle exec rake manage:change_email_address[<old_email_address>, <new_email_address>]
```

[⚙ Run rake task on production][change]

[change]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:change_email_address[from@example.org,to@example.org]

## View subscriber's recent emails

This task shows the most recent email delivery attempts made to the given user.
It takes two parameters: `email_address` (required), and `limit` (optional).
`limit` defaults to 10, but you can override this if you need to see more of
the user's history.

```bash
$ bundle exec rake manage:view_emails[<email_address>,<limit>]
```

[⚙ Run rake task on production][view_emails]

[view_emails]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:view_emails[email@example.org]

## View subscriber's subscriptions

This task shows you all of the active and inactive subscriptions for a given user.

```bash
$ bundle exec rake manage:view_subscriptions[<email_address>]
```

[⚙ Run rake task on production][view]

[view]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:view_subscriptions[email@example.org]

## Unsubscribe a subscriber from a specific subscription

This task unsubscribes one subscriber from a subscription, given an email address and a subscriber list slug.
You can find out the slug of the subscriber list by running the `view_subscriptions` rake task. above

```bash
$ bundle exec rake manage:unsubscribe_single_subscription[<email_address>,<subscriber_list_slug>]
```

[⚙ Run rake task on production][unsub_specific]

[unsub_specific]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:unsubscribe_single_subscription[email@example.org,subscriber-list-slug]

## Unsubscribe a subscriber from all emails

This task unsubscribes one subscriber from everything they have subscribed to.

```bash
$ bundle exec rake manage:unsubscribe_all_subscriptions[<email_address>]
```

[⚙ Run rake task on production][unsub]

[unsub]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:unsubscribe_all_subscriptions[email@example.org]

## Move all subscribers from one list to another

This is useful for changes such as departmental name changes, where new lists are created but subscribers should continue to receive emails.

```bash
$ bundle exec rake manage:move_all_subscribers[<from_slug>, <to_slug>]
```

You need to supply the `slug` for the source and destination subscriber lists.

[⚙ Run rake task on production][move]

[move]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:move_all_subscribers[<slug-of-old-list>,<slug-of-new-list>]

## Send a test email

To send a test email to an email address (doesn't have to be subscribed to anything):

```bash
$ bundle exec rake deliver:deliver_to_test_email[<email_address>]
```

## Resend failed emails

There are two Rake tasks available to resend emails which didn't send for
whatever reason and ended up in the failed state. This is most useful after
an incident to resend all emails that failed with a technical failure.

### Using a date range

```bash
bundle exec rake 'troubleshoot:resend_failed_emails:by_date[<from_date>,<to_date>]'
```

The date format should be in ISO8601 format, for example `2020-01-01T10:00:00Z`.
Depending on the number of emails to send, the Rake task can take a few minutes to run.

### Using email IDs

```bash
bundle exec rake 'troubleshoot:resend_failed_emails:by_id[<email_one_id>,<email_two_id>]'
```

## Count subscriptions to a subscriber list

This shows subscription counts by Immediate, Daily or Weekly:

```bash
rake report:count_subscribers['subscriber-list-slug']
```

[⚙ Run rake task on production][rake-count-subscribers]

If you need to know the number of subscriptions on a particular day:

```bash
rake report:count_subscribers_on[yyyy-mm-dd,'subscriber-list-slug']
```

[⚙ Run rake task on production][rake-count-subscribers-on]

[rake-count-subscribers]: https://deploy.blue.production.govuk.digital//job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=report:count_subscribers['subscriber-list-slug']
[rake-count-subscribers-on]: https://deploy.blue.production.govuk.digital//job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=report:count_subscribers_on[yyyy-mm-dd,'subscriber-list-slug']

## Query for subscriptions by title

This task will return subscriptions with titles containing the string provided
(not case sensitive). It is to be used in conjunction with the next rake task as
part of [renaming a country](https://docs.publishing.service.gov.uk/manual/rename-a-country.html).

```bash
$ bundle exec rake manage:find_subscriber_list_by_title[<title>]
```

It will output the number of subscriptions found and the `title` and `slug` for
each one.

## Update a subscription title

This task updates a subscription's `title`. You need to provide the `slug`,
`new_title`, and `new_slug`.

```bash
$ bundle exec rake manage:update_subscriber_list[<slug>,<new_title>,<new_slug>]
```

If successful it will confirm the change by returning the updated `title` and `slug`
in the output.
