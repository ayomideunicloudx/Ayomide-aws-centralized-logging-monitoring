# Setup Guide — AWS Console Steps

Follow in order. Estimated time: 30–45 minutes. Reference
`../configs/cloudtrail-config.md` and `../configs/alarms-and-events.md`
for exact settings as you go.

---

## 1. Enable Billing Alerts (one-time, account-wide)

1. Sign in as your account's **root user** or an admin, go to **Billing and Cost Management → Billing preferences**.
2. Check **Receive Billing Alerts** → Save preferences.
3. This must be done before the `AWS/Billing` CloudWatch metric will exist at all.

## 2. Create the SNS Topic

1. **SNS → Topics → Create topic** → type: **Standard**.
2. Name: `account-security-alerts` → Create topic.
3. **Create subscription** → Protocol: **Email** → enter your email address → Create subscription.
4. **Check your inbox and click the confirmation link** — the subscription stays "Pending confirmation" and won't deliver anything until you do.
5. Once created, go to the topic → **Edit → Access policy** → paste in `../policies/sns-topic-access-policy.json` (fill in your region and account ID) → Save.

## 3. Create the CloudWatch Billing Alarm

**Important: switch to the `us-east-1` (N. Virginia) region for this step** — billing metrics only exist there.

1. **CloudWatch → Alarms → Create alarm**.
2. **Select metric** → **Billing → Total Estimated Charge** → select `EstimatedCharges` in USD.
3. Statistic: Maximum. Period: 6 hours.
4. Condition: **Greater than** your chosen threshold (e.g. `10` for $10 — see `../configs/alarms-and-events.md`).
5. Notification: select the existing SNS topic `account-security-alerts`.
6. Name: `billing-estimated-charges-alarm` → Create alarm.

## 4. Create the S3 Bucket for CloudTrail Logs

1. Switch back to your primary working region (or stay in `us-east-1` — this bucket can be anywhere).
2. **S3 → Create bucket** → name: `cloudtrail-logs-<your-account-id>` (must be globally unique).
3. **Block Public Access**: leave **all four boxes checked**.
4. Create bucket. Leave it empty for now — CloudTrail will populate it.

## 5. Create the CloudTrail Trail

1. **CloudTrail → Trails → Create trail**.
2. Name: `account-audit-trail`.
3. **Apply trail to all regions**: **Yes**.
4. Storage location: **Use existing S3 bucket** → select `cloudtrail-logs-<your-account-id>`.
5. **Log file validation**: **Enabled**.
6. Management events: **Read** and **Write** both checked. Data events: leave unchecked (see `../configs/cloudtrail-config.md` for why).
7. Create trail.
8. Go back to the S3 bucket → **Permissions → Bucket Policy** → paste in `../policies/cloudtrail-s3-bucket-policy.json` (fill in your bucket name, region, and account ID) → Save. (CloudTrail may have already added a similar policy automatically — merge or replace with this version so it matches exactly.)

## 6. Create the EventBridge Rule for Root Login Detection

1. **EventBridge → Rules → Create rule**.
2. Name: `root-account-login-detected`. Event bus: **default**.
3. Rule type: **Rule with an event pattern**.
4. Event source: **AWS events or EventBridge partner events**.
5. Choose **Custom pattern (JSON editor)** and paste in the event pattern from `../configs/alarms-and-events.md`.
6. Target: **SNS topic** → select `account-security-alerts`.
7. Create rule.

## 7. Validate

1. Edit `../scripts/verify-monitoring.sh` with your account ID and region if needed.
2. Run:
   ```bash
   chmod +x scripts/verify-monitoring.sh
   ./scripts/verify-monitoring.sh
   ```
3. This checks: the trail is logging, the billing alarm exists and is in `OK`/`INSUFFICIENT_DATA` state, the SNS subscription is confirmed, and the EventBridge rule is enabled.

## 8. (Optional) Test the Root Login Alert for Real

Only do this if you're comfortable briefly signing in as root: sign out,
sign back in using the account's root credentials, then sign out again.
You should receive an email alert within a minute or two. This is the
single best way to prove the whole pipeline — CloudTrail → EventBridge →
SNS — actually works end to end.

## 9. Teardown (if you want to remove this later)

This project is cheap enough that you likely want to **keep it running**
even after removing everything else in the portfolio — it costs pennies
and protects you from surprise bills on anything you build next. If you
do want to remove it:

1. Delete the EventBridge rule.
2. Delete the CloudWatch billing alarm.
3. Delete the CloudTrail trail.
4. Empty and delete the `cloudtrail-logs-<your-account-id>` S3 bucket.
5. Delete the SNS topic (this also removes its subscription).
