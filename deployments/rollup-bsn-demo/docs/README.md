
<p align="center">  
  <h1>Babylon Rollup BSN Demo — Setup Overview</h1>  
</p>

This demo provides a full local setup of the Babylon Rollup BSN Integration, illustrating the core components and step-by-step process to become a rollup BSN participant.

---

## Running the Demo ▶️

Start the entire demo environment with:

```bash
make run-rollup-bsn-demo
```

This command launches a suite of Docker containers orchestrating the full demo setup.

---

## What’s Included in the Demo? 🧩

The demo consists of the following running services:

- **Three local blockchains:**  
  - Babylon chain  
  - Anvil chain 
  - Bitcoin chain

- **Two EOTS services:**  
  - One for Babylon Finality Provider  
  - One for Anvil Finality Provider  

- **Two Finality Providers (FP):**  
  - Babylon FP  
  - Anvil FP  

- **Rollup BSN contracts:**  
  - Deployed on-chain to coordinate BSN participation  

---

## Purpose of This Demo 🎯

This demo walks you through setting up the full Rollup BSN stack locally, showing the key steps needed to become a functional rollup BSN node.  
It demonstrates how blockchains, finality providers, and consumer rollups interoperate in a complete BSN environment.

---

## Next Steps and Documentation 📚

- To learn how to **register your chain as a Rollup BSN**, see [Rollup BSN Setup](./bsn/ROLLUP_BSN.md)  
- To learn how to **start Babylon Finality Provider manually**, see [Babylon FP Setup](./fp/BABYLON_FP.md)  
- To learn how to **start Rollup Finality Provider manually**, see [Rollup FP Setup](./fp/ROLLUP_FP.md) 
---
