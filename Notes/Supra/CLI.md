# Supra Move Project

A step-by-step guide for working with **Supra Move** on the Testnet.
This document covers **account setup**, **package creation**, **deployment**, and **interaction**.

> ℹ️ This README is intended as a **living document** — keep updating it as you add more commands, scripts, and notes.

---

## 📂 Table of Contents

1. [Setup a Supra Account](#-1-setup-a-supra-account)
2. [Create a Move Package](#-2-create-a-move-package)
3. [Compile and Deploy](#-3-compile-and-deploy)
4. [Interact with a Deployed Contract](#-4-interact-with-a-deployed-contract)
5. [Project Structure](#-5-project-structure)
6. [References](#-6-references)

---

## 🔑 1. Setup a Supra Account

### Generate a new key/profile

```bash
supra profile new accountA --network testnet
```

### Import an existing key/profile

```bash
supra profile new accountA <PRIVATE_KEY> --network testnet
```

### Change active profile

```bash
supra profile activate accountA
```

### View stored profiles

- Public keys:

  ```bash
  supra profile -l
  ```

- Private keys:

  ```bash
  supra profile -l -r
  ```

---

## 📦 2. Create a Move Package

### Initialize a new package

```bash
supra move tool init --package-dir /supra/move_workspace/exampleContract --name exampleContract
```

### Update named addresses

Edit **Move.toml**:

```toml
[addresses]
hello_blockchain = "YOUR-ADDRESS-HERE"
```

---

## ⚙️ 3. Compile and Deploy

### Compile your package

```bash
supra move tool compile --package-dir /supra/move_workspace/exampleContract
```

### Fund your account from faucet

```bash
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com
```

### Publish (deploy) your package

```bash
supra move tool publish --package-dir /supra/move_workspace/exampleContract \
  --rpc-url https://rpc-testnet.supra.com
```

---

## 🔗 4. Interact with a Deployed Contract

### Store a message on-chain

```bash
supra move tool run \
  --function-id '<hello_blockchain>::message::set_message' \
  --args string:"Hello world!" \
  --rpc-url https://rpc-testnet.supra.com
```

### View the stored message

```bash
supra move tool view \
  --function-id '<hello_blockchain>::message::get_message' \
  --args address:<hello_blockchain> \
  --rpc-url https://rpc-testnet.supra.com
```

---

## 🗂 5. Project Structure

A typical Move project looks like this:

```
exampleContract/
│── Move.toml            # Package configuration
│── sources/             # Your Move modules
│    └── message.move    # Example contract
│── build/               # Auto-generated after compile
```

---

## 📚 6. References

- [Supra Move: Aptos → Supra Cheatsheet](https://docs.supra.com/network/move/aptos-to-supra-cheatsheet)
- [Supra Multisig Guide](https://docs.supra.com/network/move/supra-multisig-guide)
- [Supra Developer Docs](https://docs.supra.com/)
