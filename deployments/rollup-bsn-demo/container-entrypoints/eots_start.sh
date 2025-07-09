#!/bin/bash
set -eo pipefail

EOTS_HOME="${EOTS_HOME:-/home/babylonEotsHome}"
EOTS_KEY_NAME="${EOTS_KEY_NAME:-babylon-key}"

# Add key and capture output
output=$(eotsd keys add "$EOTS_KEY_NAME" --home "$EOTS_HOME" --keyring-backend test 2>&1)
echo "$output"

# Extract pubkey_hex from output (compatible with BusyBox grep)
pubkey_hex=$(echo "$output" | grep '^  pubkey_hex:' | awk '{print $2}')

if [[ -n "$pubkey_hex" ]]; then
  echo "$pubkey_hex" > "$EOTS_HOME/${EOTS_KEY_NAME}-bk-pk"
  echo "Saved pubkey_hex to $EOTS_HOME/${EOTS_KEY_NAME}-bk-pk"
else
  echo "Failed to extract pubkey_hex"
fi

sleep 10

# Start EOTS service
eotsd start --home "$EOTS_HOME" --rpc-listener ":15813"