#!/bin/bash
set -eo pipefail

FP_HOME="${FP_HOME:-/home/babylonFPHome}"
FP_KEY_NAME="${FP_KEY_NAME:-babylon-key}"

# Add keys and capture output
output=$(fpd keys add "$FP_KEY_NAME" --home "$FP_HOME" --keyring-backend test 2>&1)
echo "$output"

# Extract address using jq
address=$(echo "$output" | jq -r '.address')

sleep 10

if [[ -n "$address" && "$address" != "null" ]]; then
  echo "Extracted address: $address"
  # Fund the extracted address
  bash /home/babylonFpHome/fund-address.sh "$address"
else
  echo "Failed to extract address"
fi

# Start FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45661" &
FPD_PID=$!

# Give FP daemon time to start
sleep 10

# Read EOTS public key hex
eots_pk=$(cat /home/babylonEotsHome/babylon-key-bk-pk)

# Create finality provider with dynamic EOTS pubkey
fpd create-finality-provider \
  --daemon-address 127.0.0.1:45661 \
  --chain-id chain-test \
  --eots-pk "$eots_pk" \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name "$FP_KEY_NAME" \
  --moniker "Babylon FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Babylon network" \
  --home "$FP_HOME"

echo "Create finality provider finished. Restarting FP daemon..."

# Stop FP daemon gracefully
kill "$FPD_PID"
sleep 5

if kill -0 "$FPD_PID" 2>/dev/null; then
  echo "FP daemon did not stop gracefully, force killing..."
  kill -9 "$FPD_PID"
else
  echo "FP daemon stopped gracefully."
fi

# Print Babylon FP info and save output
output=$(bash /home/babylonFpHome/print-babylon-fp.sh)
echo "$output" > /home/babylonFpHome/babylon-fp-output.log

# Extract btc_pk from JSON output
btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')

if [[ -n "$btc_pk" && "$btc_pk" != "null" ]]; then
  echo "Babylon FP BTC Public Key:"
  echo "$btc_pk"
  echo "$btc_pk" > "$FP_HOME/${FP_KEY_NAME}-bk-pk"
  echo "Saved btc_pk to $FP_HOME/${FP_KEY_NAME}-bk-pk"
else
  echo "Failed to extract Babylon FP BTC public key."
fi

# Delegate BTC using the extracted btc_pk
bash /home/babylonFpHome/delegate-btc-babylon-fp.sh "$btc_pk"

# Wait for delegation propagation
sleep 10

# Restart FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45661"
