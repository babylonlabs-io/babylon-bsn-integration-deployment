#!/bin/bash

FP_HOME="${FP_HOME:-/home/babylonFPHome}"
FP_KEY_NAME="${FP_KEY_NAME:-babylon-key}"


# Initialize FP
# Not needed since we copy pre-configured fpd.conf to $FP_HOME
# fpd init --home "$FP_HOME

# Add keys and capture output
output=$(fpd keys add "$FP_KEY_NAME" --home "$FP_HOME" --keyring-backend test 2>&1)

echo "$output"

# Extract address using jq
address=$(echo "$output" | jq -r '.address')

sleep 10
if [ -n "$address" ] && [ "$address" != "null" ]; then
  echo "Extracted address: $address"
  
  # Call the funding script with the extracted address
  bash /home/babylonFpHome/fund-address.sh "$address"   
else
  echo "Failed to extract address"
fi

# Start the FP daemon
fpd start --home "$FP_HOME" --rpc-listener ":45661" &

# Get the PID if you want to wait or manage later
FPD_PID=$!

# Give FP daemon some time to start
sleep 10

# Read EOTS public key hex from mounted volume
eots_pk=$(cat /home/babylonEotsHome/babylon-key-bk-pk)

# Run create-finality-provider with dynamic EOTS pk
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

# Kill the background daemon
kill $FPD_PID

if kill -0 $FPD_PID 2>/dev/null; then
  echo "FP daemon did not stop gracefully, force killing..."
  kill -9 $FPD_PID
else
  echo "FP daemon stopped gracefully."
fi

output=$(bash /home/babylonFpHome/print-babylon-fp.sh)

# Call the script to print Babylon FP
# Save full output to a log file (optional)
echo "$output" > /home/babylonFpHome/babylon-fp-output.log

# Extract and display only the btc_pk from the output JSON
btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')

if [ -n "$btc_pk" ] && [ "$btc_pk" != "null" ]; then
  echo "Babylon FP BTC Public Key:"
  echo "$btc_pk"
  echo "$btc_pk" > "$FP_HOME/${FP_KEY_NAME}-bk-pk"
  echo "Saved btc_pk to $FP_HOME/${FP_KEY_NAME}-bk-pk"
else
  echo "Failed to extract Babylon FP BTC public key."
fi

# Call delegate script with btc_pk as argument
bash /home/babylonFpHome/delegate-btc-babylon-fp.sh "$btc_pk"

# Wait 10 seconds for delegation to propagate
sleep 10

# Restart the FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45661" 