<p align="center">  
  <h1>Babylon Container Entrypoints</h1>  
</p>

---

## Overview 🚀

This directory contains container entrypoint scripts that automate the setup and startup of core BSN modules.  
Each script handles initialization tasks like adding keys, configuring daemons, deploying contracts, and starting necessary background services.  
They simplify running your Babylon node environment by bundling these repetitive steps into easy-to-run scripts

---

## Entrypoint Scripts 🛠️

### [`eots_start.sh`](./eots_start.sh)  
Sets up and starts the EOTS service.  
- Adds keys to the keyring  
- Extracts and saves the public key hex  
- Starts the `eotsd` daemon with the configured RPC listener  

### [`babylon_fp_start.sh`](./babylon_fp_start.sh)
Sets up and starts the Babylon Finality Provider (FP) service.  
- Adds FP keys and extracts the address  
- Funds the FP account if needed  
- Starts the `fpd` daemon  
- Creates the finality provider on-chain using the EOTS pubkey  
- Stops and restarts the FP daemon to apply changes  
- Prints FP info and delegates BTC tokens  

### [`anvil_fp_start.sh`](./anvil_fp_start.sh)
Sets up and starts the Anvil Finality Provider (FP) service.  
- Waits for prerequisite services to be ready  
- Deploys the finality contract and captures its address  
- Adds FP keys and funds the account  
- Registers the consumer with the deployed contract  
- Updates FP configuration with the contract address  
- Starts the `fpd` daemon  
- Creates the finality provider on-chain  
- Handles daemon restart for applying config changes  
- Prints FP info and delegates BTC tokens alongside Babylon FP  

---
