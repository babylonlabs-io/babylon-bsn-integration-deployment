<p align="center">  
  <h1>Rollup BSNs</h1>  
</p>

> Babylon BSN integration for rollup chains

## What is this?

A complete demonstration of how rollup chains can leverage Babylon's Bitcoin security through finality providers and BTC staking

**Components:**
- 🏛️ **Babylon chain** - Private testnet providing Bitcoin security
- ⚡ **Anvil L2 rollup** - Example rollup chain being secured
- ₿ **Bitcoin regtest** - Local Bitcoin testnet for development
- 🔐 **Two EOTS services** - Cryptographic signing for each finality provider
- 👥 **Two Finality Providers** - Babylon FP and Anvil FP securing the chains
- 📋 **Rollup BSN contracts** - On-chain coordination of BSN participation

## Commands

- `make build-deployment` - 🔨 Build all components
- `make start-deployment` - 🚀 Start containers  
- `make stop-deployment` - ⏹️ Stop and cleanup

## Documentation

- **📖 [Setup Guide](docs/ROLLUP_BSN_DEMO_SETUP.md)** - Complete walkthrough of the demo architecture, components, and step-by-step setup instructions for running the BSN integration locally

- **🛠️ [Scripts](scripts/README.md)** - Detailed documentation for individual operations like deploying contracts, registering finality providers, delegating BTC, and funding addresses

- **🐳 [Container Setup](container-entrypoints/README.MD)** - Container startup logic and entrypoint scripts that handle service initialization, key generation, and automated demo execution
