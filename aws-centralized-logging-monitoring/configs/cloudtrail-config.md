# CloudTrail Configuration Reference

| Setting | Value | Reason |
|---|---|---|
| Trail name | `account-audit-trail` | |
| Apply to all regions | **Yes** | Catches activity in any region, including ones you never intentionally use |
| Management events | **Read + Write** | Full picture of account configuration changes, not just a subset |
| Data events | Off (documented as a next step) | Data events (e.g. every S3 object read) are high-volume and costly at scale — not needed for an account-wide baseline; can be scoped narrowly to specific buckets later if needed |
| Log file validation | **Enabled** | Lets you cryptographically verify the delivered log files haven't been altered — turns the trail into real evidence, not just a log |
| S3 bucket | New, dedicated bucket, e.g. `cloudtrail-logs-<your-account-id>` | Never reuse an application bucket for audit logs — different access policy, different lifecycle needs |
| S3 bucket — Block Public Access | **All 4 boxes checked** | Audit logs are exactly the kind of thing that must never be public |
| CloudWatch Logs integration | Optional (documented, off by default here) | Adds near-real-time searchability in CloudWatch Logs Insights, at extra cost — enable if you want to query trail activity without downloading S3 objects |
| SNS notification on new log file | Off | Not needed — this project's alerting comes from the billing alarm and EventBridge rule, not from "a new log file arrived" |

## Why not enable data events for everything?

Data events log every individual object-level operation (e.g. every
`GetObject` call on every S3 bucket) — for an account with S3-backed
projects like the static website and the data pipeline, this can generate
a large volume of low-value log entries relative to their cost. Management
events (who created/deleted/modified *resources*) give the highest
security value for the lowest cost, which is the right trade-off for an
account-wide baseline. Scoping data events to one or two specific
sensitive buckets is a reasonable enhancement, not a default.
