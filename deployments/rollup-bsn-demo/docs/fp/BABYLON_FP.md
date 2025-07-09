
<p align="center">  
  <h1>Babylon Finality Provider Setup</h1>  
</p>

---

## Overview 🚀

This guide explains how to manually set up the Babylon Finality Provider (FP) as part of the Babylon Rollup BSN Demo.  
You will initialize and start the EOTS service, configure and start the FP daemon, register the finality provider on-chain, and delegate BTC tokens.

---

## Step 2: Setup Babylon Finality Provider

### 2.1 Initialize and Start EOTS Service 🔐

```bash
eotsd init --home ./babylonEotsHome
eotsd keys add babylon-key --home ./babylonEotsHome --keyring-backend test
```

**Save the key response** — you'll need the `pubkey_hex` for FP registration.

```bash
eotsd start --home ./babylonEotsHome
```

**Note the RPC address** from logs:  
`RPC server listening {"address": "127.0.0.1:12582"}`

---

### 2.2 Initialize and Start Finality Provider 🏛️

```bash
fpd init --home ./babylonFpHome
fpd keys add babylon-key --home ./babylonFpHome --keyring-backend test
```

**Save the key response** — you'll need the address for funding.

Fund the FP address:  
```bash
# In babylon-bsn-integration-deployment/deployments/rollup-bsn-demo/scripts
bash ./fund-address.sh <babylon-fp-address>
```


Edit `./babylonFpHome/fpd.conf`:  
- Ensure `EOTSManagerAddress = 127.0.0.1:12582`  
- Verify other settings match your environment  

> **Note:** You can see the full example configuration file at [`../../artifacts/babylon-fp.conf`](../../artifacts/babylon-fp.conf)


```bash
fpd start --home ./babylonFpHome
```

**Note the RPC address** from logs:  
`RPC server listening {"address": "[::]:50948"}`

---

### 2.3 Register and Delegate 🎯

Register the finality provider:  
```bash
fpd create-finality-provider \
  --daemon-address 127.0.0.1:50948 \
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

**Important:** Replace `<babylon-eots-pubkey-hex>` with the pubkey_hex from step 2.1.

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

Restart the FP daemon. After about 5 minutes, you should see finality signature submissions in the logs.

---

## Babylon FP Troubleshooting ⚠️
If you see an error like this when querying the consumer chain for the activated height:

```pgsql
the BTC staking protocol is not activated yet: unknown request
```

don’t worry — this means the BTC staking protocol is still initializing. Simply wait around 10 minutes for the staking and finality protocol to activate. It will start automatically once ready.


