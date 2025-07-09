<p align="center">  
  <h1>Babylon BSN Integration</h1>  
</p>

> Complete demonstrations and integrations for Babylon BSNs

This repository contains artifacts and instructions for setting up and running Babylon BSN integrations with various chains.

## Prerequisites

1. **Docker Desktop**: Install from [Docker's official website](https://docs.docker.com/desktop/).

2. **Make**: Required for building service binaries. Installation guide available [here](https://sp21.datastructur.es/materials/guides/make-install.html).

3. **Repository Setup**:
   ```shell
   git clone git@github.com:babylonlabs-io/babylon-integration-deployment.git
   git submodule init && git submodule update
   ```

## 🚀 Quick Start - Rollup BSN Demo

To run the complete Rollup BSN demonstration:

```bash
make run-rollup-bsn-demo
```

For detailed information about the demo components and setup, visit:  
**[Rollup BSN Demo Documentation](deployments/rollup-bsn-demo/README.md)**

## 📋 BSN Integration Status

- [x] **Rollup BSN** - Complete demo with finality providers and BTC staking
- [ ] **Cosmos BSN** - Coming soon
