#!/usr/bin/env sh
# shellcheck disable=SC3037

# 0. Define configuration
BABYLON_KEY="babylon-key"
BABYLON_CHAIN_ID="chain-test"
CONSUMER_KEY="bcd-key"
CONSUMER_CHAIN_ID="bcd-test"
RELAYER_CONF_DIR=/data/relayer
CONSUMER_CONF=/data/bcd

# 1. Create a bcd testnet with Babylon contract (includes IBC setup)
./setup-bcd.sh $CONSUMER_CHAIN_ID $CONSUMER_CONF 26657 26656 6060 9090 ./babylon_contract.wasm ./btc_light_client.wasm ./btc_staking.wasm ./btc_finality.wasm

sleep 3

echo "bcd started. Status of bcd node:"
bcd status

# 2. Wait for setup to complete
echo "Setup completed. Zoneconcierge channel created during setup."

# 3. Start the IBC relayer
echo "Start the IBC relayer"
rly --home $RELAYER_CONF_DIR start bcd --debug-addr '' --flush-interval 30s > /data/relayer/relayer.log &

# Keep script running silently
while true; do
    sleep 10
done
