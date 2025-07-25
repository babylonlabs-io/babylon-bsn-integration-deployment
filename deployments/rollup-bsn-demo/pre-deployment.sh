#!/bin/sh

# Create directory to hold node and services configuration with write permission
mkdir -p .testnets && chmod o+w .testnets

# Initialize Babylon testnet with custom parameters and output config to .testnets
docker run --rm -v $(pwd)/.testnets:/data babylonlabs-io/babylond \
    babylond testnet --v 2 -o /data \
    --starting-ip-address 192.168.10.2 --keyring-backend=test \
    --chain-id chain-test --epoch-interval 10 \
    --btc-finalization-timeout 2 --btc-confirmation-depth 1 \
    --minimum-gas-prices 1ubbn \
    --btc-base-header 0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4adae5494dffff7f2002000000 \
    --btc-network regtest --additional-sender-account \
    --slashing-pk-script "76a914010101010101010101010101010101010101010188ac" \
    --slashing-rate 0.1 \
    --min-staking-time-blocks 10 \
    --min-commission-rate 0.05 \
    --covenant-quorum 1 \
    --activation-height 1 \
    --unbonding-time 5 \
    --covenant-pks "2d4ccbe538f846a750d82a77cd742895e51afcf23d86d05004a356b783902748" # Update if `covenant-keyring` directory changes

# Create subdirectories for each component's configuration
mkdir -p .testnets/bitcoin
mkdir -p .testnets/vigilante
mkdir -p .testnets/btc-staker
mkdir -p .testnets/consumer-fp
mkdir -p .testnets/covenant-emulator
mkdir -p .testnets/covenant-signer
mkdir -p .testnets/babylon-eots
mkdir -p .testnets/anvil-eots
mkdir -p .testnets/babylon-fp
mkdir -p .testnets/anvil-fp

# Copy component-specific configuration files and keyrings
cp artifacts/vigilante.yml .testnets/vigilante/vigilante.yml
cp artifacts/stakerd.conf .testnets/btc-staker/stakerd.conf
cp artifacts/covd.conf .testnets/covenant-emulator/covd.conf
cp -R artifacts/covenant-emulator-keyring .testnets/covenant-emulator/keyring-test
cp artifacts/covenant-signer.toml .testnets/covenant-signer/config.toml
cp -R artifacts/covenant-signer-keyring .testnets/covenant-signer/keyring-test

# Copy smart contracts to node configuration directory
cp -R artifacts/contracts .testnets/node0/contracts

# Copy EOTS configurations
cp artifacts/babylon-eotsd.conf .testnets/babylon-eots/eotsd.conf
cp artifacts/anvil-eotsd.conf .testnets/anvil-eots/eotsd.conf

# Copy Finality Provider start scripts, configs and helper scripts for Babylon FP
cp artifacts/babylon-fp.conf .testnets/babylon-fp/fpd.conf
cp -R artifacts/babylon-fp-keyring .testnets/babylon-fp/keyring-test

# Copy Finality Provider start scripts, configs and helper scripts for Anvil FP
cp artifacts/anvil-fp.conf .testnets/anvil-fp/fpd.conf
cp -R artifacts/anvil-fp-keyring .testnets/anvil-fp/keyring-test

# Ensure all config files and directories are writable
chmod -R 777 .testnets