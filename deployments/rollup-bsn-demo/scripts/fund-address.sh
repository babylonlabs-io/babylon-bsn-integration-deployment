#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./fund_account.sh <bbn-address> [amount] [chain-id]
#
#   <bbn-address>  Recipient account address
#   [amount]      Amount to send (default: 100000000ubbn)
#   [chain-id]    Chain ID to use (default: chain-test)

ADDRESS="$1"
AMOUNT="${2:-100000000ubbn}"
CHAIN_ID="${3:-chain-test}"

CONTAINER="babylondnode0"
HOME_DIR="/babylondhome"

if [[ -z "$ADDRESS" ]]; then
  echo "❌ Usage: bash $0 <bbn-address> [amount] [chain-id]"
  exit 1
fi

echo "💸 Funding address: $ADDRESS"
echo "  → Amount: $AMOUNT"
echo "  → Chain ID: $CHAIN_ID"

# Send funds transaction
docker exec "$CONTAINER" /bin/sh -c "
  /bin/babylond --home $HOME_DIR tx bank send test-spending-key $ADDRESS $AMOUNT \
    --fees 600000ubbn --chain-id $CHAIN_ID --keyring-backend test -y --output json
"

echo "⏳ Waiting for account to be created on-chain..."

# Poll balance until account appears or timeout
for i in {1..10}; do
  BALANCE=$(docker exec "$CONTAINER" /bin/sh -c "/bin/babylond --home $HOME_DIR query bank balances $ADDRESS --output json" | jq -r '.balances[0].amount // empty')

  if [[ -n "$BALANCE" ]]; then
    echo "✅ Account funded successfully! Balance: $BALANCE ubbn"
    exit 0
  fi

  echo "  → Attempt $i: not yet found, retrying..."
  sleep 3
done

echo "❌ Account not found after multiple attempts."
exit 1