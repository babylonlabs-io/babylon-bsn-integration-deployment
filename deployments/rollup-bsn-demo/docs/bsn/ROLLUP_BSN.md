
<p align="center">  
  <h1>Registering Rollup as a BSN Consumer</h1>  
</p>

---

## Overview 🔗

To become a part of the Babylon BSN network, your rollup needs to be registered as a BSN consumer.  
This involves deploying the finality contract on-chain and registering your consumer rollup to link it to the BSN infrastructure.

---

## Step 3: Register Consumer BSN 📝

### 3.1 Deploy Finality Contract 📜

Deploy the finality contract on the Babylon chain by running:

```bash
# From babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./deploy_finality_contract.sh
```

**Save the contract address** output by the script — you will need it for the registration step.

---

### 3.2 Register Consumer 🚀

Register the Anvil rollup as a BSN consumer by executing:

```bash
bash ./register_consumer.sh <contract-address>
```

Replace `<contract-address>` with the address from the previous step.

This step officially links your rollup to the Babylon BSN, enabling full participation.

---
