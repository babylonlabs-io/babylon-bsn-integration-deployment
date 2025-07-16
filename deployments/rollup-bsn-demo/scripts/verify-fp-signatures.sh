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
BBN_CHAIN_ID="chain-test"
FP_CONTAINER="anvil-fp"

echo "🔍 Verifying finality provider is working..."

# Function to check if a block has signatures
check_block_signature() {
  local block=$1
  local hex=$(printf "0x%x" $block)

  # Get block hash from Anvil
  local hash=$(curl -s -X POST -H "Content-Type: application/json" \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$hex\",false],\"id\":1}" \
    $ANVIL_RPC | jq -r '.result.hash' 2>/dev/null)

  if [ "$hash" != "null" ] && [ -n "$hash" ]; then
    local hash_hex=${hash#0x}

    # Query contract for signatures
    local result=$(docker exec $BABYLON_NODE sh -c \
      "babylond query wasm contract-state smart $FINALITY_CONTRACT \
      '{\"block_voters\":{\"height\":$block,\"hash_hex\":\"$hash_hex\"}}' \
      --chain-id $BBN_CHAIN_ID --output json" 2>/dev/null)

    if echo "$result" | jq -e '.data != null and (.data | length) > 0' >/dev/null 2>&1; then
      return 0  # Has signature
    fi
  fi
  return 1  # No signature
}

# Wait for FP to start submitting batches
echo "📋 Waiting for finality provider to start submitting batches..."
max_attempts=15
attempt=1
recent_batch=""

while [ $attempt -le $max_attempts ]; do
  recent_batch=$(docker logs --tail 200 $FP_CONTAINER 2>&1 | \
    grep "Successfully submitted finality signatures in a batch" | tail -1)

  if [ -n "$recent_batch" ]; then
    echo "✅ Found recent batch submission:"
    echo "   $recent_batch"
    break
  fi

  echo "⏳ Attempt $attempt/$max_attempts: No batch yet, retrying in 5s..."
  attempt=$((attempt + 1))
  sleep 5
done

if [ -z "$recent_batch" ]; then
  echo "❌ No batch submission found after $max_attempts attempts"
  echo "   → FP might not be working properly"
  exit 1
fi

# Extract start and end heights
start_height=$(echo "$recent_batch" | grep -o '"start_height": [0-9]*' | cut -d' ' -f2)
end_height=$(echo "$recent_batch" | grep -o '"end_height": [0-9]*' | cut -d' ' -f2)

if [ -z "$start_height" ] || [ -z "$end_height" ]; then
  echo "❌ Could not extract block heights from log"
  exit 1
fi

echo "📝 Submitted range: blocks $start_height to $end_height"
echo ""

# Verify signatures for each block in the range
echo "🔍 Verifying signatures exist for submitted blocks..."
all_signed=true
consecutive_count=0

for ((block=start_height; block<=end_height; block++)); do
  echo -n "   Block $block: "
  if check_block_signature $block; then
    echo "✅ HAS SIGNATURE"
    consecutive_count=$((consecutive_count + 1))
  else
    echo "❌ NO SIGNATURE"
    all_signed=false
  fi
done

echo ""

# Report results
if [ "$all_signed" = true ]; then
  echo "🎉 SUCCESS! Finality provider is working correctly!"
  echo "   → Found $consecutive_count consecutive signed blocks ($start_height-$end_height)"
  echo "   → All submitted signatures verified ✅"
  exit 0
else
  echo "⚠️ ISSUE: Some blocks are missing signatures"
  echo "   → FP claimed to submit blocks $start_height-$end_height"
  echo "   → But not all blocks have verified signatures"
  exit 1
fi
