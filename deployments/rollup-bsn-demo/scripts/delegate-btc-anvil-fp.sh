#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./delegate-btc-anvil-fp.sh <consumer_fp_btc_pk> <babylon_fp_btc_pk> [staking_time] [staking_amount]
#
#   <consumer_fp_btc_pk>  Consumer Finality Provider BTC public key
#   <babylon_fp_btc_pk>   Babylon Finality Provider BTC public key
#   [staking_time]        Staking duration in blocks (default: 10000)
#   [staking_amount]      Amount to stake in sats (default: 1000000)

# Validate input arguments
CONSUMER_FP_BTC_PK="$1"
BABYLON_FP_BTC_PK="$2"
STAKING_TIME="${3:-10000}"
STAKING_AMOUNT="${4:-1000000}"

STAKER_CONTAINER="${STAKER_CONTAINER:-btc-staker}"
BABYLON_CONTAINER="${BABYLON_CONTAINER:-babylondnode0}"

if [[ -z "$CONSUMER_FP_BTC_PK" || -z "$BABYLON_FP_BTC_PK" ]]; then
  echo "❌ Usage: bash $0 <consumer_fp_btc_pk> <babylon_fp_btc_pk> [staking_time] [staking_amount]"
  exit 1
fi

echo
echo "₿ Step 5: Creating BTC delegation..."
echo "  → Staking $STAKING_AMOUNT sats for $STAKING_TIME blocks"

# Get a BTC address from available outputs
delAddr=$(docker exec "$STAKER_CONTAINER" /bin/sh -c '/bin/stakercli dn list-outputs | jq -r ".outputs[].address" | head -n1')

if [[ -z "$delAddr" ]]; then
  echo "❌ No BTC UTXO available to delegate from"
  exit 1
fi

echo "  → Using BTC address: $delAddr"
echo "  → Delegating to:"
echo "     - Consumer FP: $CONSUMER_FP_BTC_PK"
echo "     - Babylon FP: $BABYLON_FP_BTC_PK"

# Create delegation transaction
btcTxHash=$(docker exec "$STAKER_CONTAINER" /bin/sh -c "/bin/stakercli dn stake \
  --staker-address $delAddr \
  --staking-amount $STAKING_AMOUNT \
  --finality-providers-pks $CONSUMER_FP_BTC_PK \
  --finality-providers-pks $BABYLON_FP_BTC_PK \
  --staking-time $STAKING_TIME" | jq -r '.tx_hash')

if [[ -z "$btcTxHash" || "$btcTxHash" == "null" ]]; then
  echo "❌ Failed to create BTC delegation"
  exit 1
fi

echo "✅ BTC delegation created successfully"
echo "   → TX hash: $btcTxHash"

echo
echo "⏳ Step 6: Waiting for BTC delegation activation..."

# Wait and check for delegation activation
for i in {1..30}; do
  activeDelegations=$(docker exec "$BABYLON_CONTAINER" /bin/sh -c 'babylond q btcstaking btc-delegations active -o json | jq ".btc_delegations | length"')
  
  if [[ "$activeDelegations" -ge 1 ]]; then
    echo "✅ Delegation activated after $i attempt(s)"
    exit 0
  fi

  echo "  → Attempt $i: $activeDelegations active delegations"
  sleep 10
done

echo "⚠️ Delegation not activated within 5 minutes"
exit 1