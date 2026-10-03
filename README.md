AWS CENTRALIZED LOGGING & MONITORING
A security baseline project that centralizes account activity logging and sends an immediate alert the moment the AWS root account is used to sign in plus a cost-monitoring alarm riding on the same alert channel.

## Why this project

Most AWS accounts log almost nothing by default. If someone gets into your account, or you accidentally leave something running that costs money, you often don't find out until it's too late. This project sets up two tripwires: one for a security event that should basically never happen (root login), and one for a cost event that's easy to miss (spend crossing a threshold), both routed to the same place so nothing gets lost across multiple inboxes or dashboards.

## Architecture

```
                    ┌─────────────┐
   Root login  ───► │  CloudTrail │
                    └──────┬──────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │   EventBridge    │
                  │ (root-login-     │
                  │  detection rule) │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
   Billing  ───►  │  CloudWatch      │
   threshold      │  billing alarm   │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │   SNS Topic       │
                  │  "security-alerts"│
                  └────────┬─────────┘
                           │
                           ▼
                        📧 Email
```

## What's built

- **AWS CloudTrail** — trail 'management-evemt', multi-region, log file validation enabled. Captures all account activity and stores it in an S3 bucket.
- **Amazon EventBridge rule** — `root-login-detection, filters CloudTrail-sourced console sign-in events down to just root account logins.
- **Amazon SNS topic** — security-aleert`, email subscription, used as the single notification channel for both the security rule and the billing alarm.
- **Amazon CloudWatch billing alarm** — watches the `EstimatedCharges' metric and notifies via the same SNS topic if AWS charges cross a set threshold.

## Design decisions

**Why filter for root specifically, not all activity.** The default EventBridge pattern (matching any CloudTrail API call) would fire constantly — every list, describe, or read action in the account counts as an event. That's alert fatigue: too much noise, and the one alert that actually matters gets lost in it. Root, by contrast, should almost never be used day-to-day (all regular work here is done through a scoped IAM user). A root login is rare enough that any occurrence is worth investigating immediately, so the rule filters down to exactly that.

**Why the billing alarm shares the security SNS topic.** Rather than scattering notifications across multiple topics, both "something happened that shouldn't have" and "spend is higher than expected" route to one inbox. One alert channel for account-level concerns.

## Troubleshooting notes (things that didn't work on the first try)

- An IAM user with only specific service policies attached (EC2, S3, CloudTrail) still hit `AccessDeniedException' on CloudTrail actions — AdministratorAccess was needed instead, since Quick Trail Create touches a few permissions beyond CloudTrail itself.
- AWS recently moved EventBridge's "Rules" out of the main sidebar — it now lives inside **Event buses → select a bus → Rules tab**, not as its own nav item.
- The new EventBridge "Enhanced builder" uses a drag-and-drop canvas. The event pattern JSON is directly editable in a code panel on the right once an event is dragged in.
- Console sign-in events are emitted under `source: "aws.signin"`, **not** `"aws.cloudtrail"`, even though CloudTrail is what records them. Using the wrong source causes a "discrepancy between event pattern and triggering events" error.
- Billing access for IAM users is blocked at the **account level** by default, separate from IAM policies entirely. Even with AdministratorAccess, `Billing Preferences` returned "You need permissions" until root enabled **IAM User and Role Access to Billing Information** under Account settings.

## Final working event pattern

```json
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "userIdentity": {
      "type": ["Root"]
    }
  }
}
```

## Cost

Built and run inside AWS's Free Tier. CloudTrail management events, the first SNS notifications, and CloudWatch alarms all fall within free-tier limits for an account this size — the only ongoing cost is the S3 bucket storing trail logs, which is negligible at this scale.

## What I'd do differently

- Add a second EventBridge rule for IAM policy changes, not just root logins, to widen the security coverage
- Automate the SNS topic and alarm creation with CloudFormation instead of doing it by hand through the console (this becomes its own project — see the Infrastructure as Code rebuild)
