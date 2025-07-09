#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./deploy-finality-contract.sh

# Variables
BBN_CHAIN_ID="chain-test"
CONSUMER_ID="31337"
HOME_DIR="/babylondhome"
ADMIN_KEY="test-spending-key"
CONTRACT_WASM_PATH="/contracts/op_finality_gadget.wasm"
LABEL="finality"

echo "🔍 Fetching admin address..."
admin=$(docker exec babylondnode0 /bin/sh -c \
  "/bin/babylond --home $HOME_DIR keys show $ADMIN_KEY --keyring-backend test --output json | jq -r '.address'")

echo "Using admin address: $admin"

echo "📋 Deploying finality contract..."

echo "  → Storing contract WASM..."
STORE_CMD="/bin/babylond --home $HOME_DIR tx wasm store $CONTRACT_WASM_PATH \
  --from $ADMIN_KEY --chain-id $BBN_CHAIN_ID --keyring-backend test \
  --gas auto --gas-adjustment 1.3 --fees 1000000ubbn --output json -y"
echo "    Command: $STORE_CMD"
STORE_OUTPUT=$(docker exec babylondnode0 /bin/sh -c "$STORE_CMD")
echo "    Output: $STORE_OUTPUT"

sleep 10

echo "  → Instantiating contract..."
INSTANTIATE_MSG_JSON="{\"admin\":\"$admin\",\"consumer_id\":\"$CONSUMER_ID\",\"is_enabled\":true}"
INSTANTIATE_CMD="/bin/babylond --home $HOME_DIR tx wasm instantiate 1 '$INSTANTIATE_MSG_JSON' \
  --chain-id $BBN_CHAIN_ID --keyring-backend test --fees 100000ubbn \
  --label '$LABEL' --admin $admin --from $ADMIN_KEY --output json -y"
echo "    Command: $INSTANTIATE_CMD"
INSTANTIATE_OUTPUT=$(docker exec babylondnode0 /bin/sh -c "$INSTANTIATE_CMD")
echo "    Output: $INSTANTIATE_OUTPUT"

sleep 10

finalityContractAddr=$(docker exec babylondnode0 /bin/sh -c \
  "/bin/babylond --home $HOME_DIR q wasm list-contracts-by-code 1 --output json | jq -r '.contracts[0]'")

echo "✅ Finality contract deployed at: $finalityContractAddr"
