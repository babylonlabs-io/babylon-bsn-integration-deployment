#!/bin/bash
set -e

# Configurable params
STAKER_CONTAINER=${STAKER_CONTAINER:-btc-staker}
BABYLON_CONTAINER=${BABYLON_CONTAINER:-babylondnode0}
BABYLON_FP_BTC_PK="$1"
STAKING_TIME="${2:-10000}"
STAKING_AMOUNT="${3:-1000000}"

if [ -z "$BABYLON_FP_BTC_PK" ]; then
  echo "❌ Usage: $0 <babylon_fp_btc_pk> [staking_time] [staking_amount]"
  exit 1
fi

echo ""
echo "₿ Step 5: Creating BTC delegation..."
echo "  → Staking $STAKING_AMOUNT sats for $STAKING_TIME blocks"

# Get a BTC address from available outputs
delAddr=$(docker exec $STAKER_CONTAINER /bin/sh -c '/bin/stakercli dn list-outputs | jq -r ".outputs[].address" | head -n1')

if [ -z "$delAddr" ]; then
  echo "❌ No BTC UTXO available to delegate from"
  exit 1
fi

echo "  → Using BTC address: $delAddr"
echo "  → Delegating to Babylon FP: $BABYLON_FP_BTC_PK"

# Stake BTC
btcTxHash=$(docker exec $STAKER_CONTAINER /bin/sh -c "/bin/stakercli dn stake \
  --staker-address $delAddr \
  --staking-amount $STAKING_AMOUNT \
  --finality-providers-pks $BABYLON_FP_BTC_PK \
  --staking-time $STAKING_TIME" | jq -r '.tx_hash')

if [ -z "$btcTxHash" ] || [ "$btcTxHash" = "null" ]; then
  echo "❌ Failed to create BTC delegation"
  exit 1
fi

echo "✅ BTC delegation created successfully"
echo "   → TX hash: $btcTxHash"

###############################
# Step 6: Wait for Activation #
###############################

echo ""
echo "⏳ Step 6: Waiting for BTC delegation activation..."

for i in {1..30}; do
  activeDelegations=$(docker exec $BABYLON_CONTAINER /bin/sh -c 'babylond q btcstaking btc-delegations active -o json | jq ".btc_delegations | length"')
  
  if [ "$activeDelegations" -ge 1 ]; then
    echo "✅ Delegation activated after $i attempt(s)"
    exit 0
  fi

  echo "  → Attempt $i: $activeDelegations active delegations"
  sleep 10
done

echo "⚠️ Delegation not activated within 5 minutes"
exit 1
