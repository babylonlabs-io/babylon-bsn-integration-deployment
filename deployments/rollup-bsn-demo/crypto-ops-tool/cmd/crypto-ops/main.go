package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	mathrand "math/rand"
	"os"
	"strconv"
	"time"

	"os/exec"
	"strings"

	appparams "github.com/babylonlabs-io/babylon/v3/app/params"
	"github.com/babylonlabs-io/babylon/v3/app/signingcontext"
	"github.com/babylonlabs-io/babylon/v3/crypto/eots"
	"github.com/babylonlabs-io/babylon/v3/testutil/datagen"
	bbn "github.com/babylonlabs-io/babylon/v3/types"
	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/cometbft/cometbft/crypto/merkle"
	tmproto "github.com/cometbft/cometbft/proto/tendermint/crypto"
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// TODO: The following constants are duplicated in both this Go script and demo.sh.
// Consider consolidating them into a single place.
const (
	BBN_CHAIN_ID    = "chain-test"
	CONSUMER_ID     = "consumer-id"
	KEYRING_BACKEND = "test"
	KEY_NAME        = "test-spending-key"
)

func execDockerCommand(container string, command ...string) (string, error) {
	fullCmd := append([]string{"exec", container, "/bin/sh", "-c"}, strings.Join(command, " "))
	cmd := exec.Command("docker", fullCmd...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Show both the error and the full output for debugging
		return "", fmt.Errorf("docker command failed: %v\nCommand: docker %s\nOutput: %s",
			err, strings.Join(fullCmd, " "), string(output))
	}
	return strings.TrimSpace(string(output)), nil
}

// PublicRandomnessCommitment represents the output for pub randomness operations
type PublicRandomnessCommitment struct {
	ContractMessage string `json:"contract_message"`
	PublicKey       string `json:"public_key"`
	StartHeight     uint64 `json:"start_height"`
	NumPubRand      uint64 `json:"num_pub_rand"`
	Commitment      string `json:"commitment"`
	Signature       string `json:"signature"`
}

// FinalitySignatureSubmission represents the output for finality signature operations
type FinalitySignatureSubmission struct {
	ContractMessage string `json:"contract_message"`
	PublicKey       string `json:"public_key"`
	Height          uint64 `json:"height"`
	BlockHash       string `json:"block_hash"`
	Signature       string `json:"signature"`
}

// ProofOfPossession represents the output for PoP generation
type ProofOfPossession struct {
	PopHex string `json:"pop_hex"`
}

// SerializableRandListInfo is a JSON-serializable version of datagen.RandListInfo
type SerializableRandListInfo struct {
	SRListHex     []string `json:"sr_list_hex"`    // hex encoded private randomness
	PRListHex     []string `json:"pr_list_hex"`    // hex encoded public randomness
	CommitmentHex string   `json:"commitment_hex"` // hex encoded commitment
	StartHeight   uint64   `json:"start_height"`   // original start height of the randomness
	NumPubRand    uint64   `json:"num_pub_rand"`   // number of pub randomness values
	ProofListData []struct {
		Total    uint64   `json:"total"`
		Index    uint64   `json:"index"`
		LeafHash []byte   `json:"leaf_hash"`
		Aunts    [][]byte `json:"aunts"`
	} `json:"proof_list_data"`
}

// ConvertToSerializable converts datagen.RandListInfo to SerializableRandListInfo
func ConvertToSerializable(randListInfo *datagen.RandListInfo, startHeight, numPubRand uint64) (*SerializableRandListInfo, error) {
	serializable := &SerializableRandListInfo{
		SRListHex:     make([]string, len(randListInfo.SRList)),
		PRListHex:     make([]string, len(randListInfo.PRList)),
		CommitmentHex: hex.EncodeToString(randListInfo.Commitment),
		StartHeight:   startHeight,
		NumPubRand:    numPubRand,
		ProofListData: make([]struct {
			Total    uint64   `json:"total"`
			Index    uint64   `json:"index"`
			LeafHash []byte   `json:"leaf_hash"`
			Aunts    [][]byte `json:"aunts"`
		}, len(randListInfo.ProofList)),
	}

	// Convert secret randomness list
	for i, sr := range randListInfo.SRList {
		srBytes := sr.Bytes()
		serializable.SRListHex[i] = hex.EncodeToString(srBytes[:])
	}

	// Convert public randomness list
	for i, pr := range randListInfo.PRList {
		serializable.PRListHex[i] = hex.EncodeToString(pr.MustMarshal())
	}

	// Convert proof list
	for i, proof := range randListInfo.ProofList {
		protoProof := proof.ToProto()
		serializable.ProofListData[i].Total = uint64(protoProof.Total)
		serializable.ProofListData[i].Index = uint64(protoProof.Index)
		serializable.ProofListData[i].LeafHash = protoProof.LeafHash
		serializable.ProofListData[i].Aunts = protoProof.Aunts
	}

	return serializable, nil
}

// ConvertFromSerializable converts SerializableRandListInfo back to datagen.RandListInfo
func ConvertFromSerializable(serializable *SerializableRandListInfo) (*datagen.RandListInfo, error) {
	randListInfo := &datagen.RandListInfo{
		SRList:    make([]*eots.PrivateRand, len(serializable.SRListHex)),
		PRList:    make([]bbn.SchnorrPubRand, len(serializable.PRListHex)),
		ProofList: make([]*merkle.Proof, len(serializable.ProofListData)),
	}

	// Convert commitment
	var err error
	randListInfo.Commitment, err = hex.DecodeString(serializable.CommitmentHex)
	if err != nil {
		return nil, fmt.Errorf("failed to decode commitment: %v", err)
	}

	// Convert secret randomness list
	for i, srHex := range serializable.SRListHex {
		srBytes, err := hex.DecodeString(srHex)
		if err != nil {
			return nil, fmt.Errorf("failed to decode secret randomness %d: %v", i, err)
		}
		randListInfo.SRList[i] = &eots.PrivateRand{}
		overflow := randListInfo.SRList[i].SetByteSlice(srBytes)
		if overflow {
			return nil, fmt.Errorf("failed to set secret randomness %d: overflow", i)
		}
	}

	// Convert public randomness list
	for i, prHex := range serializable.PRListHex {
		prBytes, err := hex.DecodeString(prHex)
		if err != nil {
			return nil, fmt.Errorf("failed to decode public randomness %d: %v", i, err)
		}
		if err := randListInfo.PRList[i].Unmarshal(prBytes); err != nil {
			return nil, fmt.Errorf("failed to unmarshal public randomness %d: %v", i, err)
		}
	}

	// Convert proof list
	for i, proofData := range serializable.ProofListData {
		// Create proto proof first
		protoProof := &tmproto.Proof{
			Total:    int64(proofData.Total),
			Index:    int64(proofData.Index),
			LeafHash: proofData.LeafHash,
			Aunts:    proofData.Aunts,
		}
		// Convert proto to merkle.Proof
		proof, err := merkle.ProofFromProto(protoProof)
		if err != nil {
			return nil, fmt.Errorf("failed to convert proof %d from proto: %v", i, err)
		}
		randListInfo.ProofList[i] = proof
	}

	return randListInfo, nil
}

func generateProofOfPossession(addr sdk.AccAddress, btcSK *btcec.PrivateKey, chainID string) (*ProofOfPossession, error) {
	signingContext := signingcontext.FpPopContextV0(chainID, appparams.AccBTCStaking.String())
	pop, err := datagen.NewPoPBTC(signingContext, addr, btcSK)
	if err != nil {
		return nil, fmt.Errorf("failed to generate PoP: %w", err)
	}

	popHex, err := pop.ToHexStr()
	if err != nil {
		return nil, fmt.Errorf("failed to convert PoP to hex: %w", err)
	}

	return &ProofOfPossession{
		PopHex: popHex,
	}, nil
}

// Generate public randomness and commitment (crypto only, no chain submission)
func generatePublicRandomnessCommitment(r *mathrand.Rand, contractAddr string, consumerID string, consumerFpSk *btcec.PrivateKey, startHeight, numPubRand uint64) (*datagen.RandListInfo, *bbn.BIP340PubKey, []byte, error) {
	fmt.Fprintln(os.Stderr, "  → Generating public randomness list...")

	// Follow exact test pattern: btcPK -> bip340PK -> MarshalHex()
	btcPK := consumerFpSk.PubKey()
	bip340PK := bbn.NewBIP340PubKeyFromBTCPK(btcPK)

	signingContext := signingcontext.FpRandCommitContextV0(consumerID, contractAddr)
	randListInfo, msgCommitPubRandList, err := datagen.GenRandomMsgCommitPubRandList(r, consumerFpSk, signingContext, startHeight, numPubRand)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to generate public randomness list: %v", err)
	}

	fmt.Fprintf(os.Stderr, "  → Generated %d public randomness values starting at height %d\n", numPubRand, startHeight)

	// Return the randomness info, public key, and signature for bash script to submit
	signature := msgCommitPubRandList.Sig.MustToBTCSig().Serialize()
	return randListInfo, bip340PK, signature, nil
}

// Generate finality signature (crypto only, no chain submission)
func generateFinalitySignature(r *mathrand.Rand, randListInfo *datagen.RandListInfo, consumerFpSk *btcec.PrivateKey, blockHeight, startHeight uint64, blockHash []byte, contractAddr string) (*bbn.BIP340PubKey, []byte, []byte, *merkle.Proof, error) {
	fmt.Fprintln(os.Stderr, "  → Generating finality signature...")

	// Follow exact test pattern: btcPK -> bip340PK -> MarshalHex()
	btcPK := consumerFpSk.PubKey()
	bip340PK := bbn.NewBIP340PubKeyFromBTCPK(btcPK)

	fmt.Fprintf(os.Stderr, "  → Block: height=%d, hash=%x\n", blockHeight, blockHash)

	// Create message to sign with signing context (matching contract expectations)
	// Contract expects: (signing_context || block_height || block_hash)
	signingContext := signingcontext.FpFinVoteContextV0(CONSUMER_ID, contractAddr)
	var msgToSign []byte
	msgToSign = append(msgToSign, []byte(signingContext)...)
	msgToSign = append(msgToSign, sdk.Uint64ToBigEndian(blockHeight)...)
	msgToSign = append(msgToSign, blockHash...)

	// Calculate randomness index relative to the start height
	if blockHeight < startHeight {
		return nil, nil, nil, nil, fmt.Errorf("block height %d is before randomness start height %d", blockHeight, startHeight)
	}

	// Calculate the valid range for this randomness batch
	endHeight := startHeight + uint64(len(randListInfo.SRList)) - 1
	if blockHeight > endHeight {
		return nil, nil, nil, nil, fmt.Errorf("block height %d is outside the committed randomness range [%d-%d] (start_height=%d, num_pub_rand=%d)",
			blockHeight, startHeight, endHeight, startHeight, len(randListInfo.SRList))
	}

	randIndex := int(blockHeight - startHeight)
	if randIndex >= len(randListInfo.SRList) {
		// This should never happen with the above checks, but keep as safety net
		return nil, nil, nil, nil, fmt.Errorf("internal error: block height %d requires randomness index %d, but only %d randomness values available (start_height=%d)",
			blockHeight, randIndex, len(randListInfo.SRList), startHeight)
	}

	// Generate EOTS signature using the calculated randomness index
	fmt.Fprintf(os.Stderr, "  → Generating EOTS signature using randomness index %d for height %d...\n", randIndex, blockHeight)
	sig, err := eots.Sign(consumerFpSk, randListInfo.SRList[randIndex], msgToSign)
	if err != nil {
		return nil, nil, nil, nil, fmt.Errorf("failed to generate EOTS signature: %v", err)
	}
	eotsSig := bbn.NewSchnorrEOTSSigFromModNScalar(sig)

	// Return all the components needed for bash script to submit
	publicRandomness := randListInfo.PRList[randIndex].MustMarshal()
	signature := eotsSig.MustMarshal()
	proof := randListInfo.ProofList[randIndex]

	fmt.Fprintf(os.Stderr, "  ✅ Finality signature generated for block height %d using randomness index %d\n", blockHeight, randIndex)

	return bip340PK, publicRandomness, signature, proof, nil
}

func printUsage() {
	fmt.Printf(`Usage: %s <command> [args...]

Commands:
  generate-keypair                                      - Generate a new BTC key pair
  generate-pop <private_key_hex> <babylon_address>      - Generate Proof of Possession for FP creation
  
  # Crypto-only operations (recommended)
  generate-pub-rand-commitment <private_key_hex> <contract_addr> <consumer_id> <start_height> <num_pub_rand> - Generate randomness and commitment data (crypto only)
  generate-finality-sig <private_key_hex> <contract_addr> <block_height> - Generate finality signature (crypto only, reads rand_list_info_json from stdin)
  
  # Legacy combined operations (crypto + chain submission)
  commit-pub-rand <private_key_hex> <contract_addr> <start_height> <num_pub_rand> - Commit pub randomness only
  submit-finality-sig <private_key_hex> <contract_addr> <block_height> - Submit finality signature only (reads rand_list_info_json from stdin)
  commit-and-finalize <private_key_hex> <contract_addr> <start_height> <num_pub_rand> - Commit pub randomness and submit finality signature (legacy)
  
Examples:
  %s generate-keypair
  %s generate-pop abc123... bbn1...
  %s generate-pub-rand-commitment abc123... bbn1contract... consumer-id 1 100
  echo '{...randListInfoJson...}' | %s generate-finality-sig abc123... bbn1contract... 1
  %s commit-pub-rand abc123... bbn1contract... 1 100
  echo '{...randListInfoJson...}' | %s submit-finality-sig abc123... bbn1contract... 1
  %s commit-and-finalize abc123... bbn1contract... 1 100
  
Output: All commands output JSON that can be parsed by bash scripts
  
`, os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0], os.Args[0])
}

func main() {
	// Configure Babylon address prefixes
	appparams.SetAddressPrefixes()

	// Initialize random seed
	mathrand.Seed(time.Now().UnixNano())
	r := mathrand.New(mathrand.NewSource(time.Now().UnixNano()))

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "generate-keypair":
		// Generate random BTC key pair exactly like the tests do
		fpSk, _, err := datagen.GenRandomBTCKeyPair(r)
		if err != nil {
			log.Fatalf("Failed to generate BTC key pair: %v", err)
		}

		// Follow exact test pattern: btcPK -> bip340PK -> MarshalHex()
		btcPK := fpSk.PubKey()
		bip340PK := bbn.NewBIP340PubKeyFromBTCPK(btcPK)
		btcPkHex := bip340PK.MarshalHex()
		fpPrivKeyHex := hex.EncodeToString(fpSk.Serialize())

		output := map[string]string{
			"public_key":  btcPkHex,
			"private_key": fpPrivKeyHex,
		}

		jsonOutput, err := json.Marshal(output)
		if err != nil {
			log.Fatalf("Failed to marshal output: %v", err)
		}

		fmt.Println(string(jsonOutput))

	case "generate-pop":
		if len(os.Args) < 5 {
			fmt.Println("Error: Missing arguments for generate-pop")
			printUsage()
			os.Exit(1)
		}

		privKeyHex := os.Args[2]
		babylonAddr := os.Args[3]
		chainID := os.Args[4]

		// Parse the private key
		privKeyBytes, err := hex.DecodeString(privKeyHex)
		if err != nil {
			log.Fatalf("Invalid private key hex: %v", err)
		}

		fpSk, _ := btcec.PrivKeyFromBytes(privKeyBytes)

		// Parse the Babylon address
		addr, err := sdk.AccAddressFromBech32(babylonAddr)
		if err != nil {
			log.Fatalf("Invalid Babylon address: %v", err)
		}

		pop, err := generateProofOfPossession(addr, fpSk, chainID)
		if err != nil {
			log.Fatalf("Failed to generate proof of possession: %v", err)
		}

		jsonOutput, err := json.Marshal(pop)
		if err != nil {
			log.Fatalf("Failed to marshal output: %v", err)
		}

		fmt.Println(string(jsonOutput))

	case "generate-pub-rand-commitment":
		if len(os.Args) < 7 {
			fmt.Println("Error: Missing arguments for generate-pub-rand-commitment")
			printUsage()
			os.Exit(1)
		}

		privKeyHex := os.Args[2]
		contractAddr := os.Args[3]
		consumerID := os.Args[4]
		startHeightStr := os.Args[5]
		numPubRandStr := os.Args[6]

		// Parse the private key
		privKeyBytes, err := hex.DecodeString(privKeyHex)
		if err != nil {
			log.Fatalf("Invalid private key hex: %v", err)
		}

		fpSk, _ := btcec.PrivKeyFromBytes(privKeyBytes)

		// Parse start height and num pub rand
		startHeight, err := strconv.ParseUint(startHeightStr, 10, 64)
		if err != nil {
			log.Fatalf("Invalid start height: %v", err)
		}

		numPubRand, err := strconv.ParseUint(numPubRandStr, 10, 64)
		if err != nil {
			log.Fatalf("Invalid num pub rand: %v", err)
		}

		// Generate crypto data only
		randListInfo, bip340PK, signature, err := generatePublicRandomnessCommitment(r, contractAddr, consumerID, fpSk, startHeight, numPubRand)
		if err != nil {
			log.Fatalf("Failed to generate public randomness commitment: %v", err)
		}

		// Convert to serializable format
		serializable, err := ConvertToSerializable(randListInfo, startHeight, numPubRand)
		if err != nil {
			log.Fatalf("Failed to convert randListInfo to serializable: %v", err)
		}

		// Create output with all data needed for bash submission
		output := map[string]interface{}{
			"rand_list_info": serializable,
			"fp_pubkey_hex":  bip340PK.MarshalHex(),
			"start_height":   startHeight,
			"num_pub_rand":   numPubRand,
			"commitment":     randListInfo.Commitment,
			"signature":      signature,
		}

		jsonOutput, err := json.Marshal(output)
		if err != nil {
			log.Fatalf("Failed to marshal output: %v", err)
		}

		fmt.Println(string(jsonOutput))

	case "generate-finality-sig":
		if len(os.Args) < 5 {
			fmt.Println("Error: Missing arguments for generate-finality-sig")
			printUsage()
			os.Exit(1)
		}

		privKeyHex := os.Args[2]
		contractAddr := os.Args[3]
		blockHeightStr := os.Args[4]

		// Parse the private key
		privKeyBytes, err := hex.DecodeString(privKeyHex)
		if err != nil {
			log.Fatalf("Invalid private key hex: %v", err)
		}

		fpSk, _ := btcec.PrivKeyFromBytes(privKeyBytes)

		// Parse block height
		blockHeight, err := strconv.ParseUint(blockHeightStr, 10, 64)
		if err != nil {
			log.Fatalf("Invalid block height: %v", err)
		}

		// Generate random block hash internally (like submitFinalitySignature does)
		blockHash := datagen.GenRandomByteArray(r, 32)

		// Read randListInfo from stdin instead of command line to avoid "Argument list too long"
		fmt.Fprintln(os.Stderr, "  → Reading randomness data from stdin...")
		stdinBytes, err := io.ReadAll(os.Stdin)
		if err != nil {
			log.Fatalf("Failed to read from stdin: %v", err)
		}

		// Parse randListInfo
		var serializable SerializableRandListInfo
		if err := json.Unmarshal(stdinBytes, &serializable); err != nil {
			log.Fatalf("Failed to parse randListInfo: %v", err)
		}

		randListInfo, err := ConvertFromSerializable(&serializable)
		if err != nil {
			log.Fatalf("Failed to convert serializable to randListInfo: %v", err)
		}

		// Generate finality signature (crypto only)
		bip340PK, publicRandomness, signature, proof, err := generateFinalitySignature(r, randListInfo, fpSk, blockHeight, serializable.StartHeight, blockHash, contractAddr)
		if err != nil {
			log.Fatalf("Failed to generate finality signature: %v", err)
		}

		// Create output with all data needed for bash submission
		protoProof := proof.ToProto()
		output := map[string]interface{}{
			"fp_pubkey_hex": bip340PK.MarshalHex(),
			"height":        blockHeight,
			"pub_rand":      publicRandomness,
			"proof": map[string]interface{}{
				"total":     uint64(protoProof.Total),
				"index":     uint64(protoProof.Index),
				"leaf_hash": protoProof.LeafHash,
				"aunts":     protoProof.Aunts,
			},
			"block_hash":     blockHash,                     // Byte array for contract submission
			"block_hash_hex": hex.EncodeToString(blockHash), // Hex string for verification query
			"signature":      signature,
		}

		jsonOutput, err := json.Marshal(output)
		if err != nil {
			log.Fatalf("Failed to marshal output: %v", err)
		}

		fmt.Println(string(jsonOutput))

	default:
		fmt.Printf("Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}
