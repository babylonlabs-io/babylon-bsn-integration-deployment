#!/bin/bash

BBN_CHAIN_ID="chain-test"
HOME_DIR="/babylondhome"
ADMIN_KEY="test-spending-key"

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
bash ./scripts/fund-address.sh "$FP_ADDRESS"

# Wait a few seconds for the container and fpd daemon to fully start
sleep 5

# Run create-finality-provider inside babylon-fp container
docker exec babylon-fp rollup-fpd create-finality-provider \
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

#echo "--------------------------------"

# =========================
# 3. Deploy Rollup BSN Contract
# =========================

# Run deploy script and capture its output
deploy_output=$(bash ./scripts/deploy-finality-contract.sh)
echo "$deploy_output"

# Extract finality contract address from output
finalityContractAddr=$(echo "$deploy_output" | grep "✅ Finality contract deployed at:" | awk -F": " '{print $2}')
echo "Saved finality contract address: $finalityContractAddr"

# Update config with deployed contract address
FPD_CONF="./.testnets/anvil-fp/fpd.conf"
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|^FinalityContractAddress *=.*|FinalityContractAddress = $finalityContractAddr|" "$FPD_CONF"
else
  sed -i "s|^FinalityContractAddress *=.*|FinalityContractAddress = $finalityContractAddr|" "$FPD_CONF"
fi

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
bash ./scripts/fund-address.sh "$FP_ADDRESS"

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

sleep 5

# Print Anvil FP info and save output
output=$(bash ./scripts/print-anvil-fp.sh)
anvil_btc_pk=$(echo "$output" | tail -n +2 | jq -r '.[0].btc_pk')
echo "Anvil FP BTC Public Key: $anvil_btc_pk"

# =========================
# 6. Add Finality Providers to Allowlist
# =========================
echo "anvil_btc_pk: $anvil_btc_pk (length: ${#anvil_btc_pk})"

allowlist_msg=$(cat <<EOF
{
  "add_to_allowlist": {
    "fp_pubkey_hex_list": [
      "$anvil_btc_pk"
    ]
  }
}
EOF
)

echo "Adding finality providers to allowlist…"
ALLOW_JSON=$(docker exec babylondnode0 sh -c \
  "babylond --home $HOME_DIR tx wasm execute $finalityContractAddr '$allowlist_msg' \
     --from $ADMIN_KEY --chain-id $BBN_CHAIN_ID --keyring-backend test \
     --gas auto --gas-adjustment 1.3 \
     --fees 1000000ubbn \
     --broadcast-mode sync \
     --output json -y")
echo ">>> raw output <<<"
echo "$ALLOW_JSON"

# Quick error bail if CosmWasm returned a code field
if echo "$ALLOW_JSON" | jq -e 'has("code") and .code != 0' >/dev/null; then
  echo "❌ execute failed: $(echo "$ALLOW_JSON" | jq -r '.raw_log')"
  exit 1
fi

# Grab the txhash and query its full result
ALLOW_TX=$(echo "$ALLOW_JSON" | jq -r '.txhash')
echo "✔️ got txhash: $ALLOW_TX"
echo "Fetching full tx result…"
TX_JSON=$(docker exec babylondnode0 babylond --home $HOME_DIR query tx $ALLOW_TX \
  --chain-id $BBN_CHAIN_ID -o json 2>/dev/null)

echo "Full tx result:"
echo "$TX_JSON" | jq .

# If the on‑chain query shows an error, print logs and exit
if echo "$TX_JSON" | jq -e '.code != 0' >/dev/null; then
  echo "❌ on‑chain query failed: $(echo "$TX_JSON" | jq -r '.raw_log')"
  exit 1
fi

echo "✅ tx succeeded, logs above"
sleep 10

# =========================
# 7. Delegate BTC to Anvil FP
# =========================

# Delegate BTC using the extracted anvil_btc_pk and btc_pk
bash ./scripts/delegate-btc-anvil-fp.sh "$anvil_btc_pk" "$btc_pk"
echo "--------------------------------"

# =========================
# 8. Verify FP signatures and public randomness
# =========================
# Wait a few seconds for delegation to be processed
sleep 5

bash ./scripts/verify-fp-signatures.sh "$finalityContractAddr"