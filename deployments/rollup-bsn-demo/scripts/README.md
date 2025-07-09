
<p align="center">  
  <h1>Utility Scripts</h1>  
</p>

---

## Overview 🚀

This directory contains utility scripts for managing and interacting with Rollup BSN finality providers as well babylon Genesis FP.  
You can use them to deploy contracts, create BTC delegations, register consumers, and query provider information.  
They’re also great for testing and experimenting with the system.



## Scripts 📜

### [`check-tx.sh`](./check-tx.sh)  
Check transaction status inside a container

```bash
bash check-tx.sh <tx_hash> [container] [home_dir]
```

---

### [`delegate-btc-anvil-fp.sh`](./delegate-btc-anvil-fp.sh)  
Create BTC delegation to consumer and Babylon finality providers. To delegate to consumer you need to delegate to Babylon as well

```bash
bash delegate-btc-anvil-fp.sh <consumer_fp_btc_pk> <babylon_fp_btc_pk> [staking_time] [staking_amount]
```

---

### [`delegate-btc-babylon-fp.sh`](./delegate-btc-babylon-fp.sh)  
Create BTC delegation to Babylon finality provider only. Simplified version focusing solely on Babylon FP

```bash
bash delegate-btc-babylon-fp.sh <babylon_fp_btc_pk> [staking_time] [staking_amount]
```

---

### [`deploy-finality-contract.sh`](./deploy-finality-contract.sh)  
Deploy and instantiate the rollup finality contract on Babylon chain

```bash
bash deploy-finality-contract.sh
```

---

### [`fund_account.sh`](./fund_account.sh)  
Fund a given BBN address with test tokens. Waits until the account balance is confirmed on-chain

```bash
bash fund_account.sh <bbn-address> [amount] [chain-id]
```

---

### [`print-anvil-fp.sh`](./print-fp.sh)  
Print Anvil finality providers. Quickly see which FPs are linked to Anvil BSN

```bash
bash print-anvil-fp.sh
```

---

### [`print-babylon-fp.sh`](./print-babylon-fp.sh)  
Print Babylon finality providers. List all Babylon network finality providers

```bash
bash print-babylon-fp.sh
```

---

### [`register_consumer.sh`](./register_consumer.sh)  
Register a consumer with the finality contract

```bash
bash register_consumer.sh [finality_contract_address]
```




## Contributing 🤝
These scripts are made for everyone to use and adapt.
If you notice something missing or want to improve anything, feel free to open a pull request — contributions are always welcome!
