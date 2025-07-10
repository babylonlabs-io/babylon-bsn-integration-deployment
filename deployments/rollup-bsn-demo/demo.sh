#!/bin/bash

# Wait a few seconds for everything to be ready
sleep 10

# =========================
# 1. EOTS setup
# =========================

echo "Init babylon eots keys..."
babylon_eotsd_pk=$(docker exec -t babylon-eots /bin/sh -c '
  yes y | eotsd keys add babylon-key --home=/home/babylonEotsHome --keyring-backend=test --rpc-client "127.0.0.1:15813" --output=json
' | sed -n '/^{/,/^}/p' | jq -r '.pubkey_hex')
echo "babylon-eotsd-pk: $babylon_eotsd_pk"

echo "--------------------------------"
echo "Init anvil eots keys..."
anvil_eotsd_pk=$(docker exec -t anvil-eots /bin/sh -c '
  yes y | eotsd keys add anvil-key --home=/home/anvilEotsHome --keyring-backend=test --rpc-client "127.0.0.1:15817" --output=json
' | sed -n '/^{/,/^}/p' | jq -r '.pubkey_hex')
echo "anvil-eotsd-pk: $anvil_eotsd_pk"
echo "--------------------------------"
# =========================
# 2. Babylon FP setup
# =========================

# Restart babylon-fp container so it picks up keys and config
echo "Restarting babylon-fp container..."
docker restart babylon-fp

# Predefined FP address matching babylon-fp keyring (example address)
FP_ADDRESS="bbn1mnas3qgsfs6lhh2k2kykew036uk2asu4hwggxs"

echo "Using predefined Babylon FP address: $FP_ADDRESS"

# Fund babylon fp address
./scripts/fund-address.sh "$FP_ADDRESS"

# Wait a few seconds for the container and fpd daemon to fully start
sleep 5

# Run create-finality-provider inside babylon-fp container
docker exec babylon-fp fpd create-finality-provider \
  --daemon-address 127.0.0.1:45661 \
  --chain-id chain-test \
  --eots-pk "$babylon_eotsd_pk" \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name babylon-key \
  --moniker "Babylon FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Babylon network" \
  --home /home/babylonFpHome

# Restart babylon-fp container so it picks up keys and config
echo "Restarting babylon-fp container..."
docker restart babylon-fp

# Print Babylon FP info and save output
output=$(bash ./scripts/print-babylon-fp.sh)
btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')
echo "Babylon FP BTC Public Key: $btc_pk"

# Delegate BTC using the extracted btc_pk
bash ./scripts/delegate-btc-babylon-fp.sh "$btc_pk"
#echo "--------------------------------"

# =========================
# 3. Deploy Rollup BSN Contract
# =========================

# Run deploy script and capture its output
deploy_output=$(bash ./scripts/deploy-finality-contract.sh)

# Extract finality contract address from output
finalityContractAddr=$(echo "$deploy_output" | grep "✅ Finality contract deployed at:" | awk -F": " '{print $2}')
echo "Saved finality contract address: $finalityContractAddr"

# Update config with deployed contract address
FPD_CONF="./.testnets/anvil-fp/fpd.conf"
sed -i '' "s|^OPFinalityGadgetAddress *=.*|OPFinalityGadgetAddress = $finalityContractAddr|" "$FPD_CONF"

# =========================
# 4. Register Consumer BSN
# =========================

# Register consumer with finality contract
bash ./scripts/register-consumer.sh "$finalityContractAddr"

# =========================
# 5. Anvil FP setup
# =========================

# Restart anvil-fp container so it picks up keys and config
echo "Restarting anvil-fp container..."
docker restart anvil-fp

# Predefined FP address matching babylon-fp keyring (example address)
FP_ADDRESS="bbn1y7q0wsl6ff7wq9p8m7m9kmp3t5rqdg5c0d2vgd"

echo "Using predefined anvil FP address: $FP_ADDRESS"

# Fund babylon fp address
./scripts/fund-address.sh "$FP_ADDRESS"

# Wait a few seconds for the container and fpd daemon to fully start
sleep 5

# Run create-finality-provider inside anvil-fp container
docker exec anvil-fp fpd create-finality-provider \
  --daemon-address 127.0.0.1:45662 \
  --chain-id 31337 \
  --eots-pk "$anvil_eotsd_pk" \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name anvil-key \
  --moniker "Anvil FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Anvil network" \
  --home /home/anvilFpHome

# Restart anvil-fp container so it picks up keys and config
echo "Restarting anvil-fp container..."
docker restart anvil-fp

# Print Anvil FP info and save output
output=$(bash ./scripts/print-anvil-fp.sh)
anvil_btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')
echo "Anvil FP BTC Public Key: $anvil_btc_pk"

# Delegate BTC using the extracted anvil_btc_pk and btc_pk
bash ./scripts/delegate-btc-anvil-fp.sh "$anvil_btc_pk" "$btc_pk"
echo "--------------------------------"

# =========================
# 5. Verify FP signatures and public randomness
# =========================
# Wait a few seconds for delegation to be processed
sleep 30

bash ./scripts/verify-fp-signatures.sh "$finalityContractAddr"
