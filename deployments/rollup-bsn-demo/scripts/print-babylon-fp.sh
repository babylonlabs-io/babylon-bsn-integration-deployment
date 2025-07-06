#!/bin/bash
set -e

# Usage: ./print-babylon-fp.sh

CONTAINER=${CONTAINER:-babylondnode0}
HOME_DIR=${HOME_DIR:-/babylondhome}

echo "🔍 Babylon Finality Providers:"
docker exec $CONTAINER /bin/sh -c "/bin/babylond --home $HOME_DIR q btcstaking finality-providers --output json" | jq '.finality_providers'
