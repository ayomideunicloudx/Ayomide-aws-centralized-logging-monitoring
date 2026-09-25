#!/usr/bin/env bash
#
# verify-monitoring.sh — Confirms the CloudTrail trail, billing alarm, SNS
# subscription, and EventBridge rule are all actually active.
#
# Requires: AWS CLI v2, configured with credentials that can read these
# resources (a read-only IAM user/role is enough).
#
# Usage:
#   chmod +x scripts/verify-monitoring.sh
#   ./scripts/verify-monitoring.sh

set -euo pipefail

# ── EDIT THESE ───────────────────────────────────────────────────────────
TRAIL_NAME="account-audit-trail"
ALARM_NAME="billing-estimated-charges-alarm"
TOPIC_NAME="account-security-alerts"
RULE_NAME="root-account-login-detected"
AWS_PROFILE="default"
BILLING_REGION="us-east-1"   # billing alarms only exist here
# ─────────────────────────────────────────────────────────────────────────

echo "▶ Checking CloudTrail trail: $TRAIL_NAME"
STATUS=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --profile "$AWS_PROFILE" 2>/dev/null || echo "")
if echo "$STATUS" | grep -q '"IsLogging": true'; then
  echo "  ✅ Trail is actively logging."
else
  echo "  ❌ Trail not found or not logging. Check CloudTrail console."
fi

echo ""
echo "▶ Checking billing alarm: $ALARM_NAME (in $BILLING_REGION)"
ALARM=$(aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --region "$BILLING_REGION" --profile "$AWS_PROFILE" --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null || echo "None")
if [ "$ALARM" != "None" ] && [ -n "$ALARM" ]; then
  echo "  ✅ Alarm exists, current state: $ALARM"
else
  echo "  ❌ Alarm not found. Confirm you created it in us-east-1 and billing alerts are enabled."
fi

echo ""
echo "▶ Checking SNS topic subscription: $TOPIC_NAME"
TOPIC_ARN=$(aws sns list-topics --profile "$AWS_PROFILE" --query "Topics[?ends_with(TopicArn, ':$TOPIC_NAME')].TopicArn" --output text)
if [ -n "$TOPIC_ARN" ]; then
  SUB_STATUS=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --profile "$AWS_PROFILE" --query 'Subscriptions[0].SubscriptionArn' --output text)
  if [ "$SUB_STATUS" = "PendingConfirmation" ]; then
    echo "  ⚠️  Subscription is still pending — check your email and click the confirmation link."
  elif [ -n "$SUB_STATUS" ] && [ "$SUB_STATUS" != "None" ]; then
    echo "  ✅ Topic found with a confirmed subscription."
  else
    echo "  ⚠️  Topic found but no subscription detected."
  fi
else
  echo "  ❌ Topic not found."
fi

echo ""
echo "▶ Checking EventBridge rule: $RULE_NAME"
RULE_STATE=$(aws events describe-rule --name "$RULE_NAME" --profile "$AWS_PROFILE" --query 'State' --output text 2>/dev/null || echo "")
if [ "$RULE_STATE" = "ENABLED" ]; then
  echo "  ✅ Rule exists and is enabled."
else
  echo "  ❌ Rule not found or not enabled. Check EventBridge console."
fi

echo ""
echo "Done. See docs/SETUP.md if anything above shows ❌."
