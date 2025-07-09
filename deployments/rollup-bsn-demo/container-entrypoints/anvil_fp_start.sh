#!/bin/bash
set -eo pipefail

FP_HOME="${FP_HOME:-/home/anvilFPHome}"
FP_KEY_NAME="${FP_KEY_NAME:-anvil-key}"

sleep 80

# Run deploy script and capture its output
deploy_output=$(bash /home/anvilFpHome/deploy-finality-contract.sh)
echo "$deploy_output"

# Extract finality contract address from output
finalityContractAddr=$(echo "$deploy_output" | grep "✅ Finality contract deployed at:" | awk -F": " '{print $2}')

if [[ -n "$finalityContractAddr" ]]; then
  echo "Saved finality contract address: $finalityContractAddr"
else
  echo "Failed to extract finality contract address."
  exit 1
fi

# Add keys and capture output
output=$(fpd keys add "$FP_KEY_NAME" --home "$FP_HOME" --keyring-backend test 2>&1)
echo "$output"

# Extract address using jq
address=$(echo "$output" | jq -r '.address')

sleep 10

if [[ -n "$address" && "$address" != "null" ]]; then
  echo "Extracted address: $address"
  bash /home/anvilFpHome/fund-address.sh "$address"
else
  echo "Failed to extract address"
fi

# Register consumer with finality contract
bash /home/anvilFpHome/register-consumer.sh "$finalityContractAddr"

# Update config with deployed contract address
FPD_CONF="$FP_HOME/fpd.conf"
sed -i "s|^OPFinalityGadgetAddress *=.*|OPFinalityGadgetAddress = $finalityContractAddr|" "$FPD_CONF"

# Start FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45662" &
FPD_PID=$!

sleep 10

# Read EOTS public key hex
eots_pk=$(cat /home/anvilEotsHome/anvil-key-bk-pk)

# Create finality provider
fpd create-finality-provider --daemon-address 127.0.0.1:45662 \
  --chain-id 31337 \
  --eots-pk "$eots_pk" \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name "$FP_KEY_NAME" \
  --moniker "Anvil FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Anvil network" \
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

# Print Babylon FP info and save to log
output=$(bash /home/anvilFpHome/print-anvil-fp.sh)
echo "$output" > /home/anvilFpHome/anvil-fp-output.log

# Extract btc_pk from output
btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')

if [[ -n "$btc_pk" && "$btc_pk" != "null" ]]; then
  echo "Anvil FP BTC Public Key:"
  echo "$btc_pk"
  echo "$btc_pk" > "$FP_HOME/${FP_KEY_NAME}-bk-pk"
else
  echo "Failed to extract Anvil FP BTC public key."
fi

# Read Babylon FP public key
babylon_fp_pk=$(cat /home/babylonFpHome/babylon-key-bk-pk)

# Delegate BTC to both Anvil and Babylon FPs
bash /home/anvilFpHome/delegate-btc-anvil-fp.sh "$btc_pk" "$babylon_fp_pk"

sleep 10

# Restart FP daemon in background
fpd start --home "$FP_HOME" --rpc-listener ":45662"