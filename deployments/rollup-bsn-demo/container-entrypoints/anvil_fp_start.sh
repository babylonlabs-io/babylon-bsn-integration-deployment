#!/bin/bash

FP_HOME="${FP_HOME:-/home/anvilFPHome}"
FP_KEY_NAME="${FP_KEY_NAME:-anvil-key}"

sleep 80

# Run deploy script and capture its output
deploy_output=$(bash /home/anvilFpHome/deploy_finality_contract.sh)

# Print full deploy logs (optional)
echo "$deploy_output"

# Extract the finality contract address from the output using grep and awk/sed
finalityContractAddr=$(echo "$deploy_output" | grep "✅ Finality contract deployed at:" | awk -F": " '{print $2}')

if [ -n "$finalityContractAddr" ]; then
  echo "Saved finality contract address: $finalityContractAddr"
else
  echo "Failed to extract finality contract address."
fi

# Add keys and capture output
output=$(fpd keys add "$FP_KEY_NAME" --home "$FP_HOME" --keyring-backend test 2>&1)

echo "$output"

# Extract address using jq
address=$(echo "$output" | jq -r '.address')

sleep 10
if [ -n "$address" ] && [ "$address" != "null" ]; then
  echo "Extracted address: $address"
  
  # Call the funding script with the extracted address
  bash /home/anvilFpHome/fund-address.sh "$address"   
else
  echo "Failed to extract address"
fi

# Register consumer
bash /home/anvilFpHome/register-consumer.sh "$finalityContractAddr"

# Path to your config file
FPD_CONF="$FP_HOME/fpd.conf"

# Replace only the OPFinalityGadgetAddress line with the deployed contract address
sed -i "s|^OPFinalityGadgetAddress *=.*|OPFinalityGadgetAddress = $finalityContractAddr|" "$FPD_CONF"

# Start the FP daemon
fpd start --home "$FP_HOME" --rpc-listener ":45662" &

# Get the PID if you want to wait or manage later
FPD_PID=$!

# Give FP daemon some time to start
sleep 10

# Read EOTS public key hex from mounted volume
eots_pk=$(cat /home/anvilEotsHome/anvil-key-bk-pk)

fpd create-finality-provider --daemon-address 127.0.0.1:45662 \
  --chain-id 31337 \
  --eots-pk "$eots_pk" \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name anvil-key \
  --moniker "Anvil FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Anvil network" \
  --home ./anvilFPHome

  echo "Create finality provider finished. Restarting FP daemon..."

# Kill the background daemon
kill $FPD_PID

if kill -0 $FPD_PID 2>/dev/null; then
  echo "FP daemon did not stop gracefully, force killing..."
  kill -9 $FPD_PID
else
  echo "FP daemon stopped gracefully."
fi

output=$(bash /home/anvilFpHome/print-anvil-fp.sh)

# Extract and display only the btc_pk from the output JSON
btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')

if [ -n "$btc_pk" ] && [ "$btc_pk" != "null" ]; then
  echo "Anvil FP BTC Public Key:"
  echo "$btc_pk"
  echo "$btc_pk" > "$FP_HOME/${FP_KEY_NAME}-bk-pk"
else
  echo "Failed to extract Anvil FP BTC public key."
fi

# Read EOTS public key hex from mounted volume
babylon_fp_pk=$(cat /home/babylonFpHome/babylon-key-bk-pk)

# Call delegate script with btc_pk as argument
bash /home/anvilFpHome/delegate-btc-anvil-fp.sh "$btc_pk" "$babylon_fp_pk"

# Wait 10 seconds for delegation to propagate
sleep 10

# Restart the FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45662" 