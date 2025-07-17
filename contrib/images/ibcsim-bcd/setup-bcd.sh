#!/bin/bash

display_usage() {
	echo "Missing parameters. Please check if all parameters were specified."
	echo "Usage: setup-bcd.sh [CHAIN_ID] [CHAIN_DIR] [RPC_PORT] [P2P_PORT] [PROFILING_PORT] [GRPC_PORT] [BABYLON_CONTRACT_CODE_FILE] [BTC_LC_CONTRACT_CODE_FILE] [BTCSTAKING_CONTRACT_CODE_FILE] [BTCFINALITY_CONTRACT_CODE_FILE]"
	echo "Example: setup-bcd.sh test-chain-id ./data 26657 26656 6060 9090 ./babylon_contract.wasm ./btc_light_client.wasm ./btc_staking.wasm ./btc_finality.wasm"
	exit 1
}

BINARY=bcd
DENOM=stake
BASEDENOM=ustake
KEYRING=--keyring-backend="test"
SILENT=1

redirect() {
	if [ "$SILENT" -eq 1 ]; then
		"$@" >/dev/null 2>&1
	else
		"$@"
	fi
}

if [ "$#" -lt "9" ]; then
	display_usage
	exit 1
fi

CHAINID=$1
CHAINDIR=$2
RPCPORT=$3
P2PPORT=$4
PROFPORT=$5
GRPCPORT=$6
BABYLON_CONTRACT_CODE_FILE=$7
BTC_LC_CONTRACT_CODE_FILE=$8
BTCSTAKING_CONTRACT_CODE_FILE=$9
BTCFINALITY_CONTRACT_CODE_FILE=${10}

# ensure the binary exists
if ! command -v $BINARY &>/dev/null; then
	echo "$BINARY could not be found"
	exit
fi

# Delete chain data from old runs
echo "Deleting $CHAINDIR/$CHAINID folders..."
rm -rf $CHAINDIR/$CHAINID &>/dev/null
rm $CHAINDIR/$CHAINID.log &>/dev/null

echo "Creating $BINARY instance: home=$CHAINDIR | chain-id=$CHAINID | p2p=:$P2PPORT | rpc=:$RPCPORT | profiling=:$PROFPORT | grpc=:$GRPCPORT"

# Add dir for chain, exit if error
if ! mkdir -p $CHAINDIR/$CHAINID 2>/dev/null; then
	echo "Failed to create chain folder. Aborting..."
	exit 1
fi
# Build genesis file incl account for passed address
coins="100000000000$DENOM,100000000000$BASEDENOM"
delegate="50000000000$DENOM"

redirect $BINARY --home $CHAINDIR/$CHAINID --chain-id $CHAINID init $CHAINID
sleep 1
$BINARY --home $CHAINDIR/$CHAINID keys add validator $KEYRING --output json >$CHAINDIR/$CHAINID/validator_seed.json 2>&1
sleep 1
$BINARY --home $CHAINDIR/$CHAINID keys add user $KEYRING --output json >$CHAINDIR/$CHAINID/key_seed.json 2>&1
sleep 1
redirect $BINARY --home $CHAINDIR/$CHAINID genesis add-genesis-account $($BINARY --home $CHAINDIR/$CHAINID keys $KEYRING show user -a) $coins
sleep 1
redirect $BINARY --home $CHAINDIR/$CHAINID genesis add-genesis-account $($BINARY --home $CHAINDIR/$CHAINID keys $KEYRING show validator -a) $coins
sleep 1
redirect $BINARY --home $CHAINDIR/$CHAINID genesis gentx validator $delegate $KEYRING --chain-id $CHAINID
sleep 1
redirect $BINARY --home $CHAINDIR/$CHAINID genesis collect-gentxs
sleep 1

# Set proper defaults and change ports
echo "Change settings in config.toml and genesis.json files..."

# Use temporary files to avoid permission issues with mounted volumes
cp $CHAINDIR/$CHAINID/config/config.toml /tmp/config.toml.tmp
sed 's#"tcp://127.0.0.1:26657"#"tcp://0.0.0.0:'"$RPCPORT"'"#g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's#"tcp://0.0.0.0:26656"#"tcp://0.0.0.0:'"$P2PPORT"'"#g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's#"localhost:6060"#"localhost:'"$PROFPORT"'"#g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's/timeout_commit = "5s"/timeout_commit = "1s"/g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's/max_body_bytes = 1000000/max_body_bytes = 1000000000/g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's/timeout_propose = "3s"/timeout_propose = "1s"/g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
sed 's/index_all_keys = false/index_all_keys = true/g' /tmp/config.toml.tmp > /tmp/config1.tmp && mv /tmp/config1.tmp /tmp/config.toml.tmp
cp /tmp/config.toml.tmp $CHAINDIR/$CHAINID/config/config.toml

cp $CHAINDIR/$CHAINID/config/app.toml /tmp/app.toml.tmp
sed 's/minimum-gas-prices = ""/minimum-gas-prices = "0.00001ustake"/g' /tmp/app.toml.tmp > /tmp/app1.tmp && mv /tmp/app1.tmp /tmp/app.toml.tmp
sed 's#"tcp://0.0.0.0:1317"#"tcp://0.0.0.0:1318"#g' /tmp/app.toml.tmp > /tmp/app1.tmp && mv /tmp/app1.tmp /tmp/app.toml.tmp # ensure port is not conflicted with Babylon
cp /tmp/app.toml.tmp $CHAINDIR/$CHAINID/config/app.toml

cp $CHAINDIR/$CHAINID/config/genesis.json /tmp/genesis.json.tmp
sed 's/"bond_denom": "stake"/"bond_denom": "'"$DENOM"'"/g' /tmp/genesis.json.tmp > /tmp/genesis1.tmp && mv /tmp/genesis1.tmp /tmp/genesis.json.tmp
cp /tmp/genesis.json.tmp $CHAINDIR/$CHAINID/config/genesis.json

# Clean up temporary files
rm -f /tmp/config.toml.tmp /tmp/config1.tmp /tmp/app.toml.tmp /tmp/app1.tmp /tmp/genesis.json.tmp /tmp/genesis1.tmp

# sed -i '' 's#index-events = \[\]#index-events = \["message.action","send_packet.packet_src_channel","send_packet.packet_sequence"\]#g' $CHAINDIR/$CHAINID/config/app.toml

# Modify governance parameters for faster testing
echo "Updating governance parameters for faster testing..."

# Use temporary files to avoid permission issues with mounted volumes
GENESIS_TEMP="/tmp/genesis.json.tmp"
GENESIS_WORK="/tmp/genesis_work.tmp"
cp $CHAINDIR/$CHAINID/config/genesis.json "$GENESIS_TEMP"

# Apply governance parameter modifications
sed 's/"voting_period": "[^"]*"/"voting_period": "60s"/g' "$GENESIS_TEMP" > "$GENESIS_WORK" && mv "$GENESIS_WORK" "$GENESIS_TEMP"
sed 's/"amount": "10000000"/"amount": "1000000"/g' "$GENESIS_TEMP" > "$GENESIS_WORK" && mv "$GENESIS_WORK" "$GENESIS_TEMP"
sed 's/"max_deposit_period": "[^"]*"/"max_deposit_period": "30s"/g' "$GENESIS_TEMP" > "$GENESIS_WORK" && mv "$GENESIS_WORK" "$GENESIS_TEMP"

# Copy the modified file back and clean up
cp "$GENESIS_TEMP" $CHAINDIR/$CHAINID/config/genesis.json
rm -f "$GENESIS_TEMP" "$GENESIS_WORK"

# Start
echo "Starting $BINARY..."
$BINARY --home $CHAINDIR/$CHAINID start --pruning=nothing --grpc-web.enable=false --grpc.address="0.0.0.0:$GRPCPORT" --log_level trace --trace --log_format 'plain' --log_no_color 2>&1 | tee $CHAINDIR/$CHAINID.log &
sleep 20

# Echo the command with expanded variables
echo "Bootstrapping contracts..."

ADMIN=$(bcd --home $CHAINDIR/$CHAINID keys show user --keyring-backend test -a)

# 1. Store wasm contract codes and get their code IDs
echo "Storing wasm contract codes..."

# Store babylon contract
echo "Storing babylon contract code..."
$BINARY --home $CHAINDIR/$CHAINID tx wasm store "$BABYLON_CONTRACT_CODE_FILE" $KEYRING --from user --chain-id $CHAINID --gas 200000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y
sleep 5
BABYLON_CODE_ID=1

# Store btc light client contract  
echo "Storing btc light client contract code..."
$BINARY --home $CHAINDIR/$CHAINID tx wasm store "$BTC_LC_CONTRACT_CODE_FILE" $KEYRING --from user --chain-id $CHAINID --gas 200000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y
sleep 5
BTC_LC_CODE_ID=2

# Store btc staking contract
echo "Storing btc staking contract code..."
$BINARY --home $CHAINDIR/$CHAINID tx wasm store "$BTCSTAKING_CONTRACT_CODE_FILE" $KEYRING --from user --chain-id $CHAINID --gas 200000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y
sleep 5
BTC_STAKING_CODE_ID=3

# Store btc finality contract
echo "Storing btc finality contract code..."
$BINARY --home $CHAINDIR/$CHAINID tx wasm store "$BTCFINALITY_CONTRACT_CODE_FILE" $KEYRING --from user --chain-id $CHAINID --gas 200000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y
sleep 5
BTC_FINALITY_CODE_ID=4

# 2. Prepare init messages
echo "Preparing contract init messages..."
NETWORK="regtest"
BTC_CONFIRMATION_DEPTH=1
BTC_FINALIZATION_TIMEOUT=2
BABYLON_TAG="01020304"
NOTIFY_COSMOS_ZONE=false

# Encode init messages in base64
BTC_LC_INIT_MSG='{"network":"'$NETWORK'","btc_confirmation_depth":'$BTC_CONFIRMATION_DEPTH',"checkpoint_finalization_timeout":'$BTC_FINALIZATION_TIMEOUT'}'
BTC_LC_INIT_MSG_B64=$(echo -n "$BTC_LC_INIT_MSG" | base64 -w 0)

BTC_STAKING_INIT_MSG='{"admin":"'$ADMIN'"}'
BTC_STAKING_INIT_MSG_B64=$(echo -n "$BTC_STAKING_INIT_MSG" | base64 -w 0)

BTC_FINALITY_INIT_MSG='{"admin":"'$ADMIN'"}'
BTC_FINALITY_INIT_MSG_B64=$(echo -n "$BTC_FINALITY_INIT_MSG" | base64 -w 0)

# Create babylon contract init message
BABYLON_INIT_MSG='{
  "network": "'$NETWORK'",
  "babylon_tag": "'$BABYLON_TAG'",
  "btc_confirmation_depth": '$BTC_CONFIRMATION_DEPTH',
  "checkpoint_finalization_timeout": '$BTC_FINALIZATION_TIMEOUT',
  "notify_cosmos_zone": '$NOTIFY_COSMOS_ZONE',
  "btc_light_client_code_id": '$BTC_LC_CODE_ID',
  "btc_light_client_msg": "'$BTC_LC_INIT_MSG_B64'",
  "btc_staking_code_id": '$BTC_STAKING_CODE_ID',
  "btc_staking_msg": "'$BTC_STAKING_INIT_MSG_B64'",
  "btc_finality_code_id": '$BTC_FINALITY_CODE_ID',
  "btc_finality_msg": "'$BTC_FINALITY_INIT_MSG_B64'",
  "btc_light_client_initial_header": "{\"header\": {\"version\": 536870912, \"prev_blockhash\": \"000000c0a3841a6ae64c45864ae25314b40fd522bfb299a4b6bd5ef288cae74d\", \"merkle_root\": \"e666a9797b7a650597098ca6bf500bd0873a86ada05189f87073b6dfdbcaf4ee\", \"time\": 1599332844, \"bits\": 503394215, \"nonce\": 9108535}, \"height\": 2016, \"total_work\": \"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkY98OU=\"}",
  "consumer_name": "test-consumer",
  "consumer_description": "test-consumer-description"
}'

# 3. Instantiate babylon contract
echo "Instantiating babylon contract..."
INSTANTIATE_RESP=$($BINARY --home $CHAINDIR/$CHAINID tx wasm instantiate $BABYLON_CODE_ID "$BABYLON_INIT_MSG" --admin $ADMIN --label "babylon-contract" $KEYRING --from user --chain-id $CHAINID --gas 20000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y --output json)
sleep 10

# Extract contract addresses from transaction logs
echo "Querying contract addresses..."
TX_HASH=$(echo "$INSTANTIATE_RESP" | jq -r '.txhash')
sleep 5

# Query the transaction to get contract addresses
TX_RESULT=$($BINARY --home $CHAINDIR/$CHAINID query tx $TX_HASH --node http://localhost:$RPCPORT --output json)

# Extract all contract addresses from instantiate events
# The babylon contract instantiates 3 other contracts, so we get 4 addresses total
CONTRACT_ADDRESSES=($(echo "$TX_RESULT" | jq -r '.events[] | select(.type=="instantiate") | .attributes[] | select(.key=="contract_address" or .key=="_contract_address") | .value'))

echo "Found ${#CONTRACT_ADDRESSES[@]} contract addresses:"
for i in "${!CONTRACT_ADDRESSES[@]}"; do
    echo "  Contract $((i+1)): ${CONTRACT_ADDRESSES[$i]}"
done

# Assign contract addresses based on the order they were instantiated
# 1st: Babylon contract (the main one we instantiated)
# 2nd: BTC Light Client contract (instantiated by Babylon contract)
# 3rd: BTC Staking contract (instantiated by Babylon contract)  
# 4th: BTC Finality contract (instantiated by Babylon contract)
if [ ${#CONTRACT_ADDRESSES[@]} -ge 4 ]; then
    BABYLON_ADDR=${CONTRACT_ADDRESSES[0]}
    BTC_LC_ADDR=${CONTRACT_ADDRESSES[1]}
    BTC_STAKING_ADDR=${CONTRACT_ADDRESSES[2]}
    BTC_FINALITY_ADDR=${CONTRACT_ADDRESSES[3]}
else
    echo "Error: Expected 4 contract addresses, found ${#CONTRACT_ADDRESSES[@]}"
    echo "Transaction result:"
    echo "$TX_RESULT" | jq '.events[] | select(.type=="instantiate")'
    exit 1
fi

echo "Contract addresses:"
echo "Babylon: $BABYLON_ADDR"
echo "BTC Light Client: $BTC_LC_ADDR" 
echo "BTC Staking: $BTC_STAKING_ADDR"
echo "BTC Finality: $BTC_FINALITY_ADDR"

# 4. Submit governance proposal to set BSN contracts
echo "Submitting governance proposal to set BSN contracts..."
# Query governance module address dynamically
echo "Querying governance module address..."
MODULE_ACCOUNTS=$($BINARY --home $CHAINDIR/$CHAINID query auth module-accounts --node http://localhost:$RPCPORT --output json)

# Extract gov module address using the correct JSON path
GOV_AUTHORITY=$(echo "$MODULE_ACCOUNTS" | jq -r '.accounts[] | select(.value.name=="gov") | .value.address')
echo "Extracted governance authority: '$GOV_AUTHORITY'"

if [ -z "$GOV_AUTHORITY" ] || [ "$GOV_AUTHORITY" = "null" ]; then
    echo "Error: Could not extract governance module address"
    echo "Available module accounts:"
    echo "$MODULE_ACCOUNTS" | jq -r '.accounts[] | .value.name'
    exit 1
fi

echo "Using governance authority: $GOV_AUTHORITY"

# Create proposal JSON file with correct message type
PROPOSAL_FILE="/tmp/bsn_contracts_proposal.json"
cat > "$PROPOSAL_FILE" << EOF
{
  "messages": [
    {
      "@type": "/babylonlabs.babylon.v1beta1.MsgSetBSNContracts",
      "authority": "$GOV_AUTHORITY",
      "contracts": {
        "babylon_contract": "$BABYLON_ADDR",
        "btc_light_client_contract": "$BTC_LC_ADDR",
        "btc_staking_contract": "$BTC_STAKING_ADDR",
        "btc_finality_contract": "$BTC_FINALITY_ADDR"
      }
    }
  ],
  "metadata": "Set BSN Contracts",
  "title": "Set BSN Contracts", 
  "summary": "Set contract addresses for Babylon system",
  "deposit": "1000000stake"
}
EOF

echo "Created proposal file: $PROPOSAL_FILE"
echo "Proposal content:"
cat "$PROPOSAL_FILE"

PROPOSAL_RESP=$($BINARY --home $CHAINDIR/$CHAINID tx gov submit-proposal "$PROPOSAL_FILE" $KEYRING --from user --chain-id $CHAINID --gas 2000000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y --output json)
sleep 10

# Clean up the proposal file
rm -f "$PROPOSAL_FILE"

# Extract proposal ID
PROPOSAL_TX_HASH=$(echo "$PROPOSAL_RESP" | jq -r '.txhash')
sleep 5
PROPOSAL_TX_RESULT=$($BINARY --home $CHAINDIR/$CHAINID query tx $PROPOSAL_TX_HASH --node http://localhost:$RPCPORT --output json)

echo "Debugging proposal ID extraction:"
echo "TX Hash: $PROPOSAL_TX_HASH"
echo "Proposal events:"
echo "$PROPOSAL_TX_RESULT" | jq '.events[] | select(.type=="submit_proposal")'

PROPOSAL_ID=$(echo "$PROPOSAL_TX_RESULT" | jq -r '.events[] | select(.type=="submit_proposal") | .attributes[] | select(.key=="proposal_id") | .value')

echo "Extracted proposal ID: '$PROPOSAL_ID'"

if [ -z "$PROPOSAL_ID" ] || [ "$PROPOSAL_ID" = "null" ]; then
    echo "Failed to extract proposal ID, trying alternative method..."
    # Try alternative extraction method
    PROPOSAL_ID=$(echo "$PROPOSAL_TX_RESULT" | jq -r '.events[] | select(.type=="message") | .attributes[] | select(.key=="proposal_id") | .value')
    echo "Alternative proposal ID: '$PROPOSAL_ID'"
    
    if [ -z "$PROPOSAL_ID" ] || [ "$PROPOSAL_ID" = "null" ]; then
        echo "Error: Could not extract proposal ID from transaction"
        echo "Full transaction result:"
        echo "$PROPOSAL_TX_RESULT" | jq '.'
        exit 1
    fi
fi

echo "Submitted governance proposal with ID: $PROPOSAL_ID"

# 5. Vote on the proposal
echo "Voting on proposal $PROPOSAL_ID..."
$BINARY --home $CHAINDIR/$CHAINID tx gov vote "$PROPOSAL_ID" yes $KEYRING --from validator --chain-id $CHAINID --gas 200000 --gas-prices 0.01ustake --node http://localhost:$RPCPORT -y
sleep 5

# 6. Wait for proposal to pass
echo "Waiting for proposal to pass..."
while true; do
    PROPOSAL_STATUS=$($BINARY --home $CHAINDIR/$CHAINID query gov proposal $PROPOSAL_ID --node http://localhost:$RPCPORT --output json | jq -r '.proposal.status')
    echo "  → Current proposal status: $PROPOSAL_STATUS"
    
    case "$PROPOSAL_STATUS" in
        "PROPOSAL_STATUS_PASSED")
            echo "  ✅ Proposal #$PROPOSAL_ID has passed!"
            break
            ;;
        "PROPOSAL_STATUS_REJECTED")
            echo "  ❌ Proposal #$PROPOSAL_ID was rejected!"
            exit 1
            ;;
        "PROPOSAL_STATUS_FAILED")
            echo "  ❌ Proposal #$PROPOSAL_ID failed!"
            exit 1
            ;;
        *)
            echo "  → Proposal status: $PROPOSAL_STATUS, waiting..."
            sleep 10
            ;;
    esac
done

echo "BSN contracts setup completed successfully!"