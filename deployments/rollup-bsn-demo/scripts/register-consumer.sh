#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./register_consumer.sh [finality_contract_address]

BBN_CHAIN_ID="${BBN_CHAIN_ID:-chain-test}"
CONSUMER_ID="${CONSUMER_ID:-31337}"
HOME_DIR="${HOME_DIR:-/babylondhome}"
ADMIN_KEY="${ADMIN_KEY:-test-spending-key}"
CONSUMER_NAME="${CONSUMER_NAME:-anvil-consumer}"
CONSUMER_DESC="${CONSUMER_DESC:-local Anvil Consumer}"
BABYLON_REWARDS_COMMISSION="${BABYLON_REWARDS_COMMISSION:-0.1}"

# Check finality contract address
if [[ -n "$1" ]]; then
  FINALITY_CONTRACT_ADDR="$1"
elif [[ -z "$FINALITY_CONTRACT_ADDR" ]]; then
  echo "❌ Missing FINALITY_CONTRACT_ADDR"
  exit 1
fi

echo "🔗 Registering consumer '$CONSUMER_ID'..."

REGISTER_CMD="/bin/babylond --home $HOME_DIR tx btcstkconsumer register-consumer \
  $CONSUMER_ID \"$CONSUMER_NAME\" \"$CONSUMER_DESC\" $BABYLON_REWARDS_COMMISSION $FINALITY_CONTRACT_ADDR \
  --from $ADMIN_KEY --chain-id $BBN_CHAIN_ID --keyring-backend test \
  --fees 100000ubbn --output json -y"

REGISTER_OUTPUT=$(docker exec babylondnode0 /bin/sh -c "$REGISTER_CMD")

echo "✅ Consumer registered"
echo "$REGISTER_OUTPUT" | jq -r '.txhash // .code // "No TX hash"'

sleep 5