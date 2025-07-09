#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <finality_contract_address>"
  exit 1
fi

FINALITY_CONTRACT=$1
ANVIL_RPC="http://localhost:8545"
BABYLON_NODE="babylondnode0"
HOME_DIR="/babylondhome"
MAX_BLOCKS=50
CONSECUTIVE_GOAL=5
SLEEP_INTERVAL=15

echo "🔎 Starting continuous verification loop for contract: $FINALITY_CONTRACT"

while true; do
  # Get latest block number
  response=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    $ANVIL_RPC)

  latest_block_hex=$(echo "$response" | jq -r '.result')

  if [ -z "$latest_block_hex" ] || [ "$latest_block_hex" == "null" ]; then
    echo "⚠️ Could not fetch latest block number from Anvil RPC. Retrying after $SLEEP_INTERVAL s..."
    sleep $SLEEP_INTERVAL
    continue
  fi

  hex_no_prefix=${latest_block_hex#0x}
  latest_height=$((16#$hex_no_prefix))

  start_height=$((latest_height - MAX_BLOCKS + 1))
  if [ $start_height -lt 1 ]; then
    start_height=1
  fi

  echo "ℹ️ Latest Anvil block: $latest_height"
  echo "ℹ️ Verifying from block $start_height to $latest_height"

  consecutive=0

  for (( height=start_height; height<=latest_height; height++ )); do
    hex_height=$(printf "0x%x" "$height")
    block_json=$(curl -s -X POST -H "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$hex_height\",false],\"id\":1}" \
      $ANVIL_RPC)
    block_hash=$(echo "$block_json" | jq -r '.result.hash')

    if [ -z "$block_hash" ] || [ "$block_hash" == "null" ]; then
      echo "⚠️ Could not fetch block hash for height $height, skipping..."
      consecutive=0
      continue
    fi

    block_hash_no_prefix=${block_hash#0x}
    query_msg=$(jq -n --argjson height "$height" --arg hash "$block_hash_no_prefix" \
      '{block_voters: {height: $height, hash: $hash}}')

    result=$(docker exec $BABYLON_NODE /bin/sh -c \
      "babylond --home $HOME_DIR q wasm contract-state smart $FINALITY_CONTRACT '$query_msg' --output json" 2>/dev/null || echo "{}")

    has_signature=$(echo "$result" | jq '.data != null and (.data | length) > 0')

    if [ "$has_signature" = true ]; then
      echo "✅ Signature found for block $height"
      consecutive=$((consecutive + 1))
      if [ $consecutive -ge $CONSECUTIVE_GOAL ]; then
        echo "🎉 Found $CONSECUTIVE_GOAL consecutive blocks with signatures! Verification complete."
        exit 0
      fi
    else
      echo "⚠️ No signature found for block $height"
      consecutive=0
    fi
  done

  echo "ℹ️ Did not find $CONSECUTIVE_GOAL consecutive signed blocks yet. Retrying in $SLEEP_INTERVAL seconds..."
  sleep $SLEEP_INTERVAL
done
