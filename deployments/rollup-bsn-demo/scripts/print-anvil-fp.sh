#!/usr/bin/env bash
set -eo pipefail

# Usage:
#   bash ./print-anvil-fp.sh

CONSUMER_ID="31337"
CONTAINER="${CONTAINER:-babylondnode0}"
HOME_DIR="${HOME_DIR:-/babylondhome}"

echo "🔍 Consumer Finality Providers (Consumer ID: $CONSUMER_ID):"
docker exec "$CONTAINER" /bin/sh -c \
  "/bin/babylond --home $HOME_DIR q btcstaking finality-providers $CONSUMER_ID --output json" | jq '.finality_providers'
