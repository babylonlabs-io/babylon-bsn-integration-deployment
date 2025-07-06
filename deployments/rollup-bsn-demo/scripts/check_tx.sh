#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./ccc.sh <tx_hash> [container] [home_dir]
#
#   <tx_hash>   The transaction hash to check
#   [container] Docker container name (default: babylondnode0)
#   [home_dir]  babylond --home path inside the container (default: /babylondhome)

TX_HASH="$1"
if [[ -z "$TX_HASH" ]]; then
  echo "Usage: bash $0 <tx_hash> [container] [home_dir]"
  exit 1
fi

CONTAINER="${2:-babylondnode0}"
HOME_DIR="${3:-/babylondhome}"

echo "🔍 Checking tx $TX_HASH in container $CONTAINER (home: $HOME_DIR)..."

# Query the tx; capture JSON or empty on error
RAW_JSON=$(docker exec "$CONTAINER" sh -c \
  "babylond --home $HOME_DIR q tx $TX_HASH --output json" 2>/dev/null || true)

if [[ -z "$RAW_JSON" ]]; then
  echo "❌ Transaction not found or node unreachable."
  exit 1
fi

CODE=$(echo "$RAW_JSON" | jq -r '.code // 0')

if [[ "$CODE" -eq 0 ]]; then
  echo "✅ Transaction succeeded!"
  echo "$RAW_JSON" | jq '{height: .height, txhash: .txhash, logs: .raw_log}'
  exit 0
else
  echo "🚨 Transaction failed (code=$CODE):"
  echo "$RAW_JSON" | jq '{height: .height, txhash: .txhash, code: .code, error: .raw_log}'
  exit 2
fi
