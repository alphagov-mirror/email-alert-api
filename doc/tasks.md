# Tasks

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

## Unsubscribe a list of subscribers from all emails in bulk

> **Note**
>
> The CSV file should contain email addresses in the first column. All other data will be ignored.

```shell
$ bundle exec rake manage:unsubscribe_bulk_from_csv[<path to CSV file>]
```

## Manually unsubscribe subscribers

This task unsubscribes subscribers from everything they have subscribed to.

To unsubscribe a set of subscribers in bulk from a CSV file:

```bash
$ bundle exec rake manage:unsubscribe_bulk_from_csv[<path_to_csv_file>]
```

The CSV file should have email addresses in the first column. All
other columns will be ignored.

## Move all subscribers from one list to another

This is useful for changes such as departmental name changes, where new lists are created but subscribers should continue to receive emails.

```bash
$ bundle exec rake manage:move_all_subscribers[<from_slug>, <to_slug>]
```

You need to supply the `slug` for the source and destination subscriber lists.

[⚙ Run rake task on production][move]

[move]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=manage:move_all_subscribers[<slug-of-old-list>,<slug-of-new-list>]

## Remove empty subscriber lists.

[⚙ Run rake task on production][clean]

Sometimes subscriber lists are created without any subscribers. This task can be run to get rid of these.

[clean]: https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=email-alert-api&MACHINE_CLASS=email_alert_api&RAKE_TASK=clean:remove_empty_subscriberlists%20DRY_RUN=no

## Send a test email

To send a test email to an existing subscriber:

```bash
$ bundle exec rake deliver:to_subscriber[<subscriber_id>]
```

To send a test email to an email address (doesn't have to be subscribed to anything):

```bash
$ bundle exec rake deliver:to_test_email[<email_address>]
```

## Resend emails

This task takes an array of email ids and re-sends them.

```bash
bundle exec rake deliver:resend_failed_emails[<email_one_id>, <email_two_id>]
```

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

## Export data

There are a number of tasks available which export subscriber list data into CSV files on standard output. In
particular this includes the active subscription count.

```bash
$ bundle exec rake export:csv_from_ids[<subscriber_list_id>, ...]
```

```bash
$ bundle exec rake export:csv_from_ids_at[<date>, <subscriber_list_id>, ...]
```

This is the same as above, but exports the active subscription count of the subscriber list as it was on a particular
date.

```bash
$ bundle exec rake export:csv_from_living_in_europe[<date>]
```

This is a convenience export which does the same as above but with all the "Living in Europe" taxon subscriber lists
without needing to know their IDs.

## Reports

There are a number of tasks to produce informational reports

### Content Change

```bash
$ bundle exec rake report:content_change_email_status_count[<content_change_id>]
```

This will output to the terminal a count for the given content change's
sent, pending and failed emails.

```bash
$ bundle exec rake report::content_change_failed_emails[<content_change_id>]
```

This will output to the terminal the ID and reason for failure for each of the content change's
failed emails.

### Unpublishing

```bash
$ bundle exec rake report::unpublishing[<start_date>, <end_date>]

```

This will output to the terminal a brief summary of unpublishing activity and related
ending subscriptions between the two dates. It also reports new subscriptions.
