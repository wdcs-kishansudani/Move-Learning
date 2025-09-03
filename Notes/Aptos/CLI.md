# Aptos Move Project README

A step-by-step guide for working with **Aptos Move**.
This document covers **account setup**, **project initialization**, **module deployment**, **interaction**, and **advanced features** like resource accounts and gas profiling.

---

## 📂 Table of Contents

1. [Account Setup](#-1-account-setup)
2. [Create and Manage Move Packages](#-2-create-and-manage-move-packages)
3. [Testing and Coverage](#-3-testing-and-coverage)
4. [Publishing Modules](#-4-publishing-modules)
5. [Interacting with Modules](#-5-interacting-with-modules)
6. [Local Testnet](#-6-local-testnet)
7. [Transaction Replay & Profiling](#-7-transaction-replay--profiling)
8. [Move Scripts](#-8-move-scripts)
9. [Profiles & Account Management](#-9-profiles--account-management)
10. [Resource Accounts](#-10-resource-accounts)
11. [Smart Contract Resource Accounts](#-11-smart-contract-resource-accounts)

---

## 🔑 1. Account Setup

### Initialize your account

```bash
aptos init
```

### Create profile

```bash
aptos init --profile <profile_name>
```

### Initialize a profile with custom config

```bash
aptos init \
  --assume-yes \
  --network local \
  --private-key-file private-key-a \
  --profile test-profile-1
```

### View profile

```bash
aptos config show-profiles --profile test-profile-1
```

### Look up address

```bash
aptos account lookup-address \
  --public-key-file private-key-a.pub \
  --url http://localhost:8080
```

---

## 📦 2. Create and Manage Move Packages

### Initialize a new project

```bash
aptos move init --name my_first_module
```

### Compile the module

```bash
aptos move compile --named-addresses my_first_module=default
```

### Run tests

```bash
aptos move test --named-addresses my_first_module=default
```

---

## 🧪 3. Testing and Coverage

### Run tests

```bash
aptos move test --named-addresses my_first_module=default
```

### Generate test coverage report

```bash
aptos move test --coverage
```

---

## 🚀 4. Publishing Modules

### Publish module

```bash
aptos move publish --named-addresses my_first_module=default
```

### Publish without source code

```bash
aptos move publish --included-artifacts none
```

### Publish to local network

```bash
aptos move publish \
  --profile <your-profile-name> \
  --package-dir /opt/git/aptos-core/aptos-move/move-examples/hello_blockchain \
  --named-addresses HelloBlockchain=local
```

---

## 🔗 5. Interacting with Modules

### Run function

```bash
aptos move run --function-id 'default::message::set_message' --args 'string:Hello, Aptos!'
```

---

## 🖥 6. Local Testnet

### Start a local testnet

```bash
aptos node run-local-testnet --with-indexer-api
```

### Reset the local network

```bash
aptos node run-local-testnet --force-restart
```

---

## 📊 7. Transaction Replay & Profiling

### Replay past transaction

```bash
aptos move replay --network mainnet --txn-id 581400718
```

### Benchmark transaction

```bash
aptos move replay --network mainnet --txn-id 581400718 --benchmark
```

### Gas profiling

```bash
aptos move replay --network mainnet --txn-id 581400718 --profile-gas
```

---

## 📜 8. Move Scripts

### Compile module

```bash
aptos move compile
```

### Compile script

```bash
aptos move compile-script
```

### Run script from source

```bash
aptos move run-script --script-path ./sources/transfer_half.move
```

### Run script from compiled file

```bash
aptos move run-script --compiled-script-path ./path/to/.mv
```

---

## 👤 9. Profiles & Account Management

### Export address from public key

```bash
export ADDRESS_A=$(
  aptos account lookup-address \
    --public-key-file private-key-a.pub \
    --url http://localhost:8080 \
    | jq -r '.Result'
)
echo $ADDRESS_A
```

---

## 🪪 10. Resource Accounts

### Create resource account

```bash
aptos account create-resource-account
```

### Create resource account and publish package

```bash
aptos move create-resource-account-and-publish-package
```

---

## 🏛 11. Smart Contract Resource Accounts

- **`create_resource_account`** – Creates a resource account (not funded). Retains signer access until `retrieve_resource_account_cap`.
- **`create_resource_account_and_fund`** – Creates and funds the account, signer access retained until `retrieve_resource_account_cap`.
- **`create_resource_account_and_publish_package`** – Creates resource account and publishes package. By design, signer access is lost (used for autonomous/immutable contracts).
