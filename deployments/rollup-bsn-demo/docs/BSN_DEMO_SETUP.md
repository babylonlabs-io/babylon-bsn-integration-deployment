# Babylon BSN Integration Demo - Manual Setup Guide

This guide walks through the complete manual setup of the Babylon BSN Integration Demo, including local blockchain infrastructure and finality providers for both Babylon and Anvil networks.

## Important Version Note

**Current main finality-provider commit `ff6b427d4c88bedcf826ee7cdcae06b2a49e4248` has an issue where the OP client relies on FP gadget.** 

**Use the draft PR [LINK_TO_BE_ADDED] until this reliance is fixed.**

## Overview

The demo consists of:
- **Local Infrastructure**: Bitcoin node, Babylon node, Anvil L2 rollup
- **Babylon Finality Provider**: Provides finality for Babylon network
- **Consumer BSN**: Anvil rollup registered as BSN consumer
- **Anvil Finality Provider**: Provides finality for Anvil network

## Prerequisites

- Docker and Docker Compose
- Go development environment
- Access to `babylon-bsn-integration-deployment` repository
- **Local Installation**: `eotsd` and `fpd` executables installed locally (global commands)

## Step 1: Start Local Infrastructure

All blockchain infrastructure runs in Docker containers.

```bash
# In babylon-bsn-integration-deployment repository
make run-rollup-bsn-demo
```

This starts:
- Bitcoin local node
- Babylon local node  
- Anvil node (L2 rollup emulator)
- Additional supporting services

Wait for all containers to be healthy before proceeding.

## Step 2: Setup Babylon Finality Provider

### 2.1 Initialize and Start EOTS Service

```bash
eotsd init --home ./babylonEotsHome
eotsd keys add babylon-key --home ./babylonEotsHome --keyring-backend test
```

**Save the key response** - you'll need the `pubkey_hex` for FP registration.

```bash
eotsd start --home ./babylonEotsHome
```

**Note the RPC address** from logs: `RPC server listening {"address": "127.0.0.1:12582"}`

### 2.2 Initialize and Start Finality Provider

```bash
fpd init --home ./babylonFpHome
fpd keys add babylon-key --home ./babylonFpHome --keyring-backend test
```

**Save the key response** - you'll need the address for funding.

Fund the FP address:
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./fund-address.sh <babylon-fp-address>
```

Edit `./babylonFpHome/fpd.conf`:
- Ensure `EOTSManagerAddress = 127.0.0.1:12582`
- Verify other settings match your environment

```bash
fpd start --home ./babylonFpHome
```

**Note the RPC address** from logs: `RPC server listening {"address": "[::]:50948"}`

### 2.3 Register and Delegate

Register the finality provider:
```bash
fpd create-finality-provider --daemon-address 127.0.0.1:50948 \
  --chain-id chain-test \
  --eots-pk <babylon-eots-pubkey-hex> \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name babylon-key \
  --moniker "Babylon FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Babylon network" \
  --home ./babylonFpHome
```

**Important**: Replace `<babylon-eots-pubkey-hex>` with the pubkey_hex from step 2.1.

Verify registration and get btc_pk:
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./print-babylon-fp.sh
```

Delegate BTC to the FP:
```bash
bash ./delegate-btc-babylon-fp.sh <babylon-fp-btc-pk>
```

Check delegation status:
```bash
docker exec babylondnode0 /bin/sh -c "babylond query btcstaking btc-delegations active"
```

Restart the FP. After ~5 minutes, you should see finality signature submissions in the logs.

## Step 3: Register Consumer BSN

### 3.1 Deploy Finality Contract

```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./deploy_finality_contract.sh
```

**Save the contract address** from the output.

### 3.2 Register Consumer

```bash
bash ./register_consumer.sh <contract-address>
```

This registers the Anvil rollup as a BSN consumer.

## Step 4: Setup Anvil Finality Provider

### 4.1 Initialize and Start EOTS Service

```bash
eotsd init --home ./anvilEotsHome
eotsd keys add anvil-key --home ./anvilEotsHome --keyring-backend test
```

**Save the key response** - you'll need the `pubkey_hex` for FP registration.

Configure ports to avoid conflicts with Babylon EOTS:
Edit `anvilEotsHome/eotsd.conf`:
- `RPCListener = 127.0.0.1:12582` → `127.0.0.1:12587`
- `Port = 2113` → `2117`

```bash
eotsd start --home ./anvilEotsHome
```

**Note the RPC address**: `RPC server listening {"address": "127.0.0.1:12587"}`

### 4.2 Initialize and Start Finality Provider

```bash
fpd init --home ./anvilFpHome
fpd keys add anvil-key --home ./anvilFpHome --keyring-backend test
```

**Save the key response** - you'll need the address for funding.

Fund the FP address:
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./fund-address.sh <anvil-fp-address>
```

Edit `./anvilFpHome/fpd.conf`:
- `ChainType = OPStackL2`
- `EOTSManagerAddress = 127.0.0.1:12587`
- `OPFinalityGadgetAddress = <contract-address>` (from step 3.1)
- `Port = 2112` → `2118` (metrics port)

```bash
fpd start --home ./anvilFpHome
```

**Note the RPC address** from logs for registration.

### 4.3 Register and Delegate

Register the finality provider:
```bash
fpd create-finality-provider --daemon-address <anvil-fp-rpc-address> \
  --chain-id 31337 \
  --eots-pk <anvil-eots-pubkey-hex> \
  --commission-rate 0.05 \
  --commission-max-change-rate 0.01 \
  --commission-max-rate 0.20 \
  --key-name anvil-key \
  --moniker "Anvil FP" \
  --website "https://myfinalityprovider.com" \
  --security-contact "security@myfinalityprovider.com" \
  --details "finality provider for the Anvil network" \
  --home ./anvilFpHome
```

Verify both FPs are registered:
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./print-anvil-fp.sh
```

**Critical**: Delegate BTC to BOTH Babylon and Anvil FPs:
```bash
bash ./delegate-btc-anvil-fp.sh <anvil-fp-btc-pk> <babylon-fp-btc-pk>
```

Restart the Anvil FP. After some time, you should see finality signature submissions.

## Verification and Monitoring

### Check FP Status
- Babylon FP logs: Look for finality signature submissions
- Anvil FP logs: Look for finality signature submissions
- Both should show successful batch submissions after delegation activation

### Check Delegations
```bash
docker exec babylondnode0 /bin/sh -c "babylond query btcstaking btc-delegations active"
```

### Key Monitoring Points
- EOTS services running on different ports (12582, 12587)
- FP services running on different ports (metrics: 2112, 2118)
- Finality signature submissions appearing in logs
- Delegation activation (takes ~5 minutes)

## Important Notes

1. **Port Management**: Each service needs unique ports to avoid conflicts
2. **Key Management**: Save all key responses - addresses and pubkeys are needed for later steps
3. **Delegation Requirement**: For consumer BSN FPs, you MUST delegate to both Babylon and consumer FPs
4. **Timing**: Allow ~5 minutes for delegation activation and signature submission to begin
5. **One EOTS per FP**: Each finality provider requires its own dedicated EOTS service