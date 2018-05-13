//go:generate abigen --sol nameRegistry.sol --pkg main --out nameRegistry.go
package main

import (
	"fmt"
	"log"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/accounts/keystore"
	"os"
	"bytes"
	"crypto/sha256"
)

const contractAddress = "0x84e0310c0269f2b0af076c035686872b3319732f"
const rpcUrl = "http://47.91.208.241:8801"
const defaultWalletPath = "./wallet"
const defaultWalletPassword = "123qwe"

func main() {
	wallet := keystore.NewKeyStore(defaultWalletPath,
		keystore.LightScryptN,keystore.LightScryptP)
	if len(wallet.Accounts()) == 0 {
		fmt.Println("Empty wallet, create account first.")
		os.Exit(2)
	}
	account := wallet.Accounts()[0]

	// Create an IPC based RPC connection to a remote node and instantiate a contract binding
	conn, err := ethclient.Dial(rpcUrl)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}
	simpleRegistry, err := NewSimpleRegistry(common.HexToAddress(contractAddress), conn)
	if err != nil {
		log.Fatalf("Failed to instantiate a Token contract: %v", err)
	}
	// Create an authorized transactor and spend 1 unicorn
	key, err := wallet.Export(account,defaultWalletPassword,defaultWalletPassword)
	if err != nil {
		log.Fatalf("Account export error: %v", err)
	}
	opts, err := bind.NewTransactor(bytes.NewReader(key), defaultWalletPassword)
	//auth, err := bind.NewKeyedTransactor(wallet., "my awesome super secret password")
	if err != nil {
		log.Fatalf("Failed to create authorized transactor: %v", err)
	}
	name := "Meng Guang"
	hash := sha256.Sum256([]byte(name))
	fee, err := simpleRegistry.Fee(nil)
	opts.Value =  fee

	tx, err := simpleRegistry.Reserve(opts,hash)
	if err != nil {
		log.Fatalf("Failed to request token transfer: %v", err)
	}
	fmt.Printf("Transfer pending: 0x%x\n", tx.Hash())

	address,err := simpleRegistry.GetOwner(nil,hash)
	if err != nil {
		log.Fatalf("Failed to call GetOwner: %v", err)
	}
	fmt.Println(address.Hex())
}