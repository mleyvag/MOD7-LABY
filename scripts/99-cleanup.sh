#!/bin/bash
# ============================================================
# 99-cleanup.sh — Cleanup all AWS resources
# ============================================================
set -euo pipefail

echo "🔴 Cleaning up all resources for suffix ${SUFFIX}..."

API_NAME="cuentas-api-${SUFFIX}"
FUNCTION_NAME="cuentas-lambda-${SUFFIX}"

# ── Step 1: Delete API Keys and Usage Plans ──
echo "📌 Deleting API Keys and Usage Plans..."
API_KEY_IDS=$(aws apigateway get-api-keys \
  --query "items[?name=='key-${SUFFIX}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for KEY_ID in $API_KEY_IDS; do
  [ -z "$KEY_ID" ] || [ "$KEY_ID" = "None" ] && continue
  echo "  Deleting API Key: ${KEY_ID}"
  aws apigateway delete-api-key --api-key "$KEY_ID" --no-cli-pager 2>/dev/null || true
done

PLAN_IDS=$(aws apigateway get-usage-plans \
  --query "items[?name=='plan-${SUFFIX}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for PLAN_ID in $PLAN_IDS; do
  [ -z "$PLAN_ID" ] || [ "$PLAN_ID" = "None" ] && continue
  echo "  Deleting Usage Plan: ${PLAN_ID}"
  aws apigateway delete-usage-plan --usage-plan-id "$PLAN_ID" --no-cli-pager 2>/dev/null || true
done

# ── Step 2: Delete API Gateway ──
echo "📌 Deleting API Gateway..."
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='${API_NAME}'].id" \
  --output text --no-cli-pager 2>/dev/null || echo "")

if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
  echo "  Deleting REST API: ${API_ID}"
  aws apigateway delete-rest-api --rest-api-id "$API_ID" --no-cli-pager 2>/dev/null || true
fi

# ── Step 3: Delete Lambda aliases ──
echo "📌 Deleting Lambda aliases..."
for ALIAS in test prod; do
  aws lambda delete-alias \
    --function-name "$FUNCTION_NAME" \
    --name "$ALIAS" \
    --no-cli-pager 2>/dev/null || true
done

# ── Step 4: Delete Lambda versions ──
echo "📌 Deleting Lambda versions..."
VERSIONS=$(aws lambda list-versions-by-function \
  --function-name "$FUNCTION_NAME" \
  --query "Versions[?Version!='\$LATEST'].Version" \
  --output text --no-cli-pager 2>/dev/null || echo "")

for VER in $VERSIONS; do
  [ -z "$VER" ] || [ "$VER" = "None" ] && continue
  aws lambda delete-function \
    --function-name "$FUNCTION_NAME" \
    --qualifier "$VER" \
    --no-cli-pager 2>/dev/null || true
done

# ── Step 5: Delete Lambda function ──
echo "📌 Deleting Lambda function..."
aws lambda delete-function \
  --function-name "$FUNCTION_NAME" \
  --no-cli-pager 2>/dev/null || true

# ── Step 6: Delete catalog files from S3 ──
echo "📌 Deleting catalog files from S3..."
aws s3 rm "s3://${CATALOG_BUCKET}/catalog/${SUFFIX}/" \
  --recursive --no-cli-pager 2>/dev/null || true

echo "✅ All resources cleaned up for suffix ${SUFFIX}!"
echo "🔴 Cleanup completed!"
