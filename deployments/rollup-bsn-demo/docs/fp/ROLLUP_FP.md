
<p align="center">  
  <h1>Rollup Finality Provider Setup</h1>  
</p>

---

## Overview 🚀

This guide explains how to manually set up the Rollup Finality Provider (FP) as part of the Babylon Rollup BSN Demo.  
You will initialize and start the EOTS service, configure and start the FP daemon, register the finality provider on-chain, and delegate BTC tokens.

---
## Important Version Note

> **Notice:**  
> The current `main` branch commit of the finality-provider (`ff6b427d4c88bedcf826ee7cdcae06b2a49e4248`) contains a known issue where the OP client improperly depends on the finality provider gadget. This is why this repo is referencing (`b625194767bac645492b7ae5c653ef7aa33a7a86`)
> For details, please see issue [#503](https://github.com/babylonlabs-io/finality-provider/issues/503).



## Step 4: Setup Rollup Finality Provider

### 4.1 Initialize and Start EOTS Service 🔐

```bash
eotsd init --home ./anvilEotsHome
eotsd keys add anvil-key --home ./anvilEotsHome --keyring-backend test
```

**Save the key response** — you'll need the `pubkey_hex` for FP registration.

Configure ports to avoid conflicts with Babylon EOTS:  
Edit `anvilEotsHome/eotsd.conf`:  
- Make sure `RPCListener` port is available  
- Make sure `Port` port is available   

```bash
eotsd start --home ./anvilEotsHome
```

**Note the RPC address** from logs:  
`RPC server listening {"address": "127.0.0.1:12587"}`

---

### 4.2 Initialize and Start Finality Provider 🏛️

```bash
fpd init --home ./anvilFpHome
fpd keys add anvil-key --home ./anvilFpHome --keyring-backend test
```

**Save the key response** — you'll need the address for funding.

Fund the FP address:  
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./fund-address.sh <anvil-fp-address>
```

Edit `./anvilFpHome/fpd.conf`:  
- `ChainType = OPStackL2`  
- `EOTSManagerAddress = 127.0.0.1:12587`  
- `OPFinalityGadgetAddress = <contract-address>` (from Step 3)  
- Make sure `Port` is available

> **Note:** You can see the full example configuration file at [`../../artifacts/anvil-fp.conf`](../../artifacts/anvil-fp.conf)

```bash
fpd start --home ./anvilFpHome
```

**Note the RPC address** from logs — needed for registration.

---

### 4.3 Register and Delegate 🎯

Register the finality provider:  
```bash
fpd create-finality-provider \
  --daemon-address <anvil-fp-rpc-address> \
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

Verify both Finality Providers are registered:  
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./print-anvil-fp.sh
```

**Critical:** Delegate BTC to **both** Babylon and Anvil FPs:  
```bash
bash ./delegate-btc-anvil-fp.sh <anvil-fp-btc-pk> <babylon-fp-btc-pk>
```

Restart the Anvil FP. After some time, you should see finality signature submissions.

---

## Anvil FP Troubleshooting ⚠️
If you see an error like this in the logs:

```plaintext
the finality-provider does not have voting power {"pk": "a9eeb9a2a3b587780471cb315f5beef2da94a237e332cab3d5f21383aaa92ccc", "block_height": 199}
```
don’t worry — this means the finality provider has not yet received voting power on-chain. In a few minutes it will start submitting
