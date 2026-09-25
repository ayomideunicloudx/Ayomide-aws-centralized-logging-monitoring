# Alarms & Events Reference

## CloudWatch Alarm: Billing

| Setting | Value |
|---|---|
| Alarm name | `billing-estimated-charges-alarm` |
| Namespace / Metric | `AWS/Billing` / `EstimatedCharges` |
| Region | **Must be created in `us-east-1`** — billing metrics are only published there, regardless of which region your other resources run in |
| Statistic | Maximum |
| Period | 6 hours |
| Threshold | `> $10 USD` (edit to whatever makes sense as your portfolio grows — start low so you actually see it fire once as a test) |
| Evaluation periods | 1 |
| Alarm action | Publish to `account-security-alerts` SNS topic |

**Prerequisite:** Billing alerts must be turned on once per account under
**Billing and Cost Management → Billing preferences → Receive Billing
Alerts** before this metric exists at all. Covered in `docs/SETUP.md`.

---

## EventBridge Rule: Root Account Console Sign-In

| Setting | Value |
|---|---|
| Rule name | `root-account-login-detected` |
| Event bus | `default` |
| Event pattern | see below |
| Target | `account-security-alerts` SNS topic |

**Event pattern:**

```json
{
  "detail-type": ["AWS Console Sign-In via CloudTrail"],
  "detail": {
    "userIdentity": {
      "type": ["Root"]
    },
    "responseElements": {
      "ConsoleLogin": ["Success"]
    }
  }
}
```

This matches only **successful** root console sign-ins — a failed
attempt is worth knowing about too, but is a much noisier signal (e.g.
your own typos); documented as a next-step refinement rather than
included by default.

---

## Why EventBridge here instead of a CloudWatch Logs metric filter?

A metric filter requires CloudTrail to already be delivering to
CloudWatch Logs (an extra piece of setup and cost). EventBridge's default
event bus receives CloudTrail management events directly, with no extra
plumbing — for a single, specific event pattern like "root login
happened," it's the simpler and cheaper path. Metric filters remain the
better tool for aggregating/counting patterns over time (e.g. "how many
unauthorized API calls this week") — a good next-step addition, not a
replacement for this rule.
