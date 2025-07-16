#!/usr/bin/env bash
set -eo pipefail

BBN_CHAIN_ID="chain-test"
CONSUMER_ID="31337"
HOME_DIR="/babylondhome"
ADMIN_KEY="test-spending-key"
CONTRACT_WASM_PATH="/contracts/finality.wasm"
LABEL="finality"


echo "🔍 Fetching admin address..."
admin=$(docker exec babylondnode0 sh -c \
  "babylond --home $HOME_DIR keys show $ADMIN_KEY --keyring-backend test --output json" \
  | jq -r '.address')
echo "   → $admin"

echo "🔍 Storing WASM (sync)…"
STORE_JSON=$(docker exec babylondnode0 sh -c \
  "babylond --home $HOME_DIR tx wasm store $CONTRACT_WASM_PATH \
     --from $ADMIN_KEY --chain-id $BBN_CHAIN_ID --keyring-backend test \
     --gas auto --gas-adjustment 1.3 --fees 1000000ubbn \
     --broadcast-mode sync --output json -y" 2>/dev/null)
echo "$STORE_JSON"
STORE_TX=$(echo "$STORE_JSON" | jq -r '.txhash')

sleep 10

STORE_RESULT=$(babylond query tx "$STORE_TX" --node "$NODE_RPC" --output json)

CODE_ID=$(echo "$STORE_RESULT" | jq -r '
  .events[]
  | select(.type == "store_code")
  | .attributes[]
  | select(.key == "code_id")
  | .value')

echo "✅ Code ID: $CODE_ID"

echo "🔍 Instantiating (sync)…"
INSTANT_MSG='{
  "admin": "'"$admin"'", 
  "bsn_id": "'"$CONSUMER_ID"'", 
  "min_pub_rand": 1, 
  "rate_limiting_interval": 100, 
  "max_msgs_per_interval": 1000, 
  "is_enabled": true
}'
INSTANT_JSON=$(docker exec babylondnode0 sh -c \
  "babylond --home $HOME_DIR tx wasm instantiate $CODE_ID '$INSTANT_MSG' \
     --from $ADMIN_KEY --chain-id $BBN_CHAIN_ID --keyring-backend test \
     --fees 100000ubbn --label '$LABEL' --admin $admin \
     --broadcast-mode sync --output json -y" 2>/dev/null)
echo "$INSTANT_JSON"
INSTANT_TX=$(echo "$INSTANT_JSON" | jq -r '.txhash')

sleep 10

CONTRACT_ADDR=$(docker exec babylondnode0 sh -c \
  "babylond --home $HOME_DIR q wasm list-contracts-by-code $CODE_ID --output json | jq -r '.contracts[-1]'")
echo "✅ Finality contract deployed at: $CONTRACT_ADDR"



