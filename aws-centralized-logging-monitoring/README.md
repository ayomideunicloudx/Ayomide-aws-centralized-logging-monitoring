# AWS Centralized Logging & Monitoring (Account Security Baseline)

An account-wide security and observability baseline: every API call
audited, cost anomalies caught early, and root account misuse detected in
near real-time — the layer that should exist *before* anything else gets
built, watching everything after.

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                          AWS Account (all regions)                  │
│                                                                       │
│   Every API call                    Root console sign-in            │
│        │                                    │                        │
│        ▼                                    ▼                        │
│  ┌─────────────┐                   ┌─────────────────────┐         │
│  │  CloudTrail  │                   │  EventBridge          │         │
│  │ (multi-region│                   │  (default event bus,  │         │
│  │  trail)      │                   │   rule matches root   │         │
│  └──────┬──────┘                   │   console sign-in)    │         │
│         │                          └──────────┬───────────┘         │
│         ▼                                     │                      │
│  ┌─────────────┐                              │                      │
│  │  S3 Bucket   │  (audit log archive,         │                      │
│  │  (private)   │   log file validation on)    │                      │
│  └─────────────┘                              │                      │
│                                                │                      │
│   Billing metric                              │                      │
│        │                                       │                      │
│        ▼                                       │                      │
│  ┌─────────────┐                              │                      │
│  │ CloudWatch   │                              │                      │
│  │ Billing Alarm│──────────────┐               │                      │
│  └─────────────┘               │               │                      │
│                                 ▼               ▼                      │
│                          ┌─────────────────────────┐                 │
│                          │      SNS Topic            │                 │
│                          │  (account-security-alerts) │                │
│                          └────────────┬────────────┘                 │
│                                       │                               │
│                                       ▼                               │
│                                  📧 Email alert                       │
└────────────────────────────────────────────────────────────────────┘
```

## 🎯 Design Decisions

| Decision | Reason |
|---|---|
| CloudTrail is **multi-region** | An attacker (or a mistake) in a region you're not watching is still a problem — single-region trails are a common gap |
| CloudTrail log file validation **on** | Lets you cryptographically verify the audit log itself hasn't been tampered with — meaningless as an audit trail otherwise |
| CloudTrail logs go to a **dedicated S3 bucket**, not an app bucket | Keeps audit logs separate from application data, with its own tighter access policy |
| Root login detection via **EventBridge**, not a CloudWatch Logs metric filter | EventBridge receives CloudTrail management events directly on the account's default event bus — no need to first wire CloudTrail into CloudWatch Logs just to catch this one event |
| Billing alarm uses the **`AWS/Billing` `EstimatedCharges`** metric | The single highest-value alarm for a portfolio AWS account, given ongoing costs from NAT Gateways and Multi-AZ RDS in other projects here |
| One SNS topic, email only | Keeps the alerting path simple and auditable — every alarm and rule in this project publishes to the same place, so it's one thing to check |
| Scope: billing + root login + CloudTrail (not per-project metrics yet) | This is the account-wide security baseline every AWS account should have *first* — deeper dashboards pulling in NAT Gateway/ALB/RDS metrics from other projects are a natural next step, not this one |

## 🛠️ AWS Services Used

- **AWS CloudTrail** — multi-region trail, log file validation, delivers to S3
- **Amazon S3** — private audit log archive with a CloudTrail-scoped bucket policy
- **Amazon CloudWatch** — billing alarm on the `EstimatedCharges` metric
- **Amazon EventBridge** — rule matching root account console sign-in events
- **Amazon SNS** — single topic, email subscription, receives both the billing alarm and the root-login rule
- **AWS Budgets** *(optional, documented)* — an additional layer of cost alerting beyond the CloudWatch billing alarm
- **IAM** — scoped policies for the CloudTrail→S3 delivery and SNS topic access

## 📁 Repo Structure

```
aws-centralized-logging-monitoring/
├── README.md                              ← you are here
├── docs/
│   └── SETUP.md                           ← step-by-step console build guide
├── configs/
│   ├── cloudtrail-config.md               ← trail settings reference
│   └── alarms-and-events.md               ← every alarm/rule this project creates, with thresholds and reasoning
├── policies/
│   ├── cloudtrail-s3-bucket-policy.json   ← lets CloudTrail (and only CloudTrail) write to the log bucket
│   └── sns-topic-access-policy.json       ← lets CloudWatch + EventBridge (and only them) publish to the alert topic
└── scripts/
    └── verify-monitoring.sh               ← AWS CLI script confirming the trail, alarm, subscription, and rule are all actually active
```

## 🚀 Quick Start

1. Follow [`docs/SETUP.md`](docs/SETUP.md) — enables billing alerts, creates the SNS topic, the CloudTrail trail + S3 bucket, the billing alarm, and the EventBridge rule, in order.
2. Reference [`configs/alarms-and-events.md`](configs/alarms-and-events.md) for exact thresholds and event patterns as you build.
3. Confirm the SNS email subscription (check your inbox — AWS sends a confirmation link).
4. Run:
   ```bash
   chmod +x scripts/verify-monitoring.sh
   ./scripts/verify-monitoring.sh
   ```
5. Trigger a real test: sign in as root once (if you ever legitimately need to) and confirm you receive an email within a minute or two.

## ✅ What This Proves

- Every API call across every region is recorded and tamper-evident
- An unexpected cost spike (e.g. forgetting to tear down a NAT Gateway or RDS Multi-AZ instance) triggers an email before the bill does
- Root account usage — the single highest-risk action in any AWS account — is detected and alerted on immediately, not discovered later in a CloudTrail search

## 💰 Cost Notes

This project is nearly free to run: CloudTrail's first trail is free,
S3 storage for logs is pennies, CloudWatch alarms are ~$0.10/month each,
SNS email delivery is free at this volume. **This is the cheapest project
in the portfolio and arguably the one that should be built first on any
new AWS account**, since it protects you from surprise costs in
everything else.

## 🔭 Next Steps (documented, not yet implemented)

- Pull real metrics from the VPC lab (NAT Gateway bytes processed) and three-tier app (ALB 5xx, RDS CPU) into a unified CloudWatch dashboard
- Additional CIS AWS Foundations Benchmark alarms: unauthorized API calls, IAM policy changes, console sign-in without MFA
- AWS Config for continuous compliance checking (ties into the planned IAM Security Baseline project)
- Route findings through AWS Security Hub for a single consolidated view

## 👤 About

Built by Ayomide Oladapo as a hands-on AWS portfolio project, applying
account-wide audit logging, cost alerting, and security event detection
learned through AWS Cloud Practitioner and the AWS re/Start program.
