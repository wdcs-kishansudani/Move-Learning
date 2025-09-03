# Supra Multisig Account Management Script

This README explains each step of the `supra-multisig-setup.sh` script and what happens during the multisig account creation and management process on Supra blockchain testnet.

## 📖 Script Overview

The script automates the complete workflow of creating and managing multisig accounts on Supra testnet. It consists of 14 main steps that guide you through account setup, multisig creation, smart contract deployment, and transaction management.

## 🔧 Prerequisites

- Supra CLI installed
- `jq` JSON processor
- Access to Supra testnet RPC endpoint
- Bash shell environment

## 📋 Step-by-Step Explanation

### STEP 1: Creating Owner Accounts

```bash
supra profile new default --network testnet
supra profile new accountA --network testnet
supra profile new accountB --network testnet
```

**What it does:**

- Creates three separate blockchain profiles/accounts
- Each profile has its own private key and address
- `default` will be the primary account
- `accountA` and `accountB` will be additional multisig owners
- All profiles are configured for testnet network

**Output:** Three new profiles are created with unique addresses and private keys

---

### STEP 2: Activating Default Profile

```bash
supra profile activate default
```

**What it does:**

- Sets the `default` profile as the currently active profile
- All subsequent commands will use this profile unless specified otherwise
- This becomes the primary account for initiating multisig operations

**Output:** Default profile becomes the active working profile

---

### STEP 3: Setting Environment Variables

```bash
default_addr=""
accounta_addr=""
accountb_addr=""
```

**What it does:**

- Creates placeholder variables for storing account addresses
- These need to be manually populated with actual addresses from Step 1
- Variables are used throughout the script for referencing accounts

**Required Action:** You must replace empty strings with actual addresses from profile creation

---

### STEP 4: Funding Owner Accounts

```bash
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile default
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountA
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountB
```

**What it does:**

- Requests testnet tokens from the Supra faucet for each account
- Each account receives tokens needed for transaction fees
- Connects to testnet RPC endpoint to submit funding requests

**Output:** All three accounts are funded with testnet SUPRA tokens

---

### STEP 5: Creating the Multisig Account

```bash
supra move multisig create \
    --timeout-duration 3600 \
    --num-signatures-required 2 \
    --additional-owners $accounta_addr $accountb_addr \
    --rpc-url https://rpc-testnet.supra.com
```

**What it does:**

- Creates a new multisig account with specific configuration:
  - **Timeout duration:** 3600 seconds (1 hour) - how long proposals remain valid
  - **Required signatures:** 2 out of 3 total owners
  - **Owners:** default (creator) + accountA + accountB
- Generates a unique multisig address

**Output:** New multisig account address (save this address!)

---

### STEP 6: Verifying Multisig Configuration

```bash
# Check required signatures
supra move tool view \
    --function-id 0x1::multisig_account::num_signatures_required \
    --args address:"$multisig_addr"

# Verify owners
supra move tool view \
    --function-id 0x1::multisig_account::owners \
    --args address:"$multisig_addr"

# Check sequence number
supra move tool view \
    --function-id 0x1::multisig_account::last_resolved_sequence_number \
    --args address:"$multisig_addr"
```

**What it does:**

- **First command:** Confirms the multisig requires 2 signatures
- **Second command:** Lists all owner addresses of the multisig
- **Third command:** Shows the last completed transaction sequence number (starts at 0)

**Output:** Verification that multisig is configured correctly with proper owners and signature requirements

---

### STEP 7: Preparing Module Deployment

```bash
supra move tool build-publish-payload \
    --named-addresses my_addrx=$multisig_addr \
    --json-output-file publication.json \
    --assume-yes
```

**What it does:**

- Builds a deployment package for smart contract modules
- Creates a JSON file containing all deployment information
- Sets `my_addrx` as a named address pointing to the multisig account
- Prepares the payload for multisig transaction creation

**Output:** `publication.json` file containing deployment payload

---

### STEP 8: Creating Multisig Publication Transaction

```bash
supra move multisig create-transaction \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --store-hash-only \
    --assume-yes
```

**What it does:**

- Creates a multisig transaction proposal for smart contract deployment
- Uses the payload from `publication.json`
- `--store-hash-only` means only the transaction hash is stored initially
- Transaction is created but not yet approved or executed

**Output:** New pending transaction in the multisig account (sequence number 1)

---

### STEP 9: Verifying Transaction

```bash
# Check pending transactions
supra move tool view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

# Verify the proposal
supra move multisig verify-proposal \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --sequence-number 1

# Check execution readiness
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:1
```

**What it does:**

- **First command:** Lists all pending transactions waiting for approval
- **Second command:** Verifies that the proposal matches the payload file
- **Third command:** Checks if transaction has enough signatures to execute

**Output:** Transaction verification and execution status

---

### STEP 10: Executing Deployment

```bash
supra move multisig execute-with-payload \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --profile accountA \
    --max-gas 10000 \
    --assume-yes
```

**What it does:**

- Executes the smart contract deployment transaction
- Uses `accountA` profile to sign and execute
- Sets maximum gas limit to 10,000 units
- Deploys the smart contract to the blockchain

**Output:** Smart contract is deployed and available at the multisig address

---

### STEP 11: Creating Function Transactions

```bash
supra move multisig create-transaction \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FAA::mint_to \
    --args \
        address:$accounta_addr \
        u64:1010 \
        u64:1764579073 \
    --assume-yes
```

**What it does:**

- Creates a new multisig transaction to call a smart contract function
- Calls the `mint_to` function from the `FAA` module
- **Arguments:**
  - `address:$accounta_addr` - recipient of minted tokens
  - `u64:1010` - amount to mint
  - `u64:1764579073` - possibly a timestamp or additional parameter

**Output:** New pending function call transaction

---

### STEP 12: Managing Function Execution

```bash
# Get next sequence number
seq=$(supra move tool view \
    --function-id 0x1::multisig_account::next_sequence_number \
    --args address:"$multisig_addr" | jq -r .result[0])

# Check pending transactions
supra move tool view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

# Check execution status
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:$seq
```

**What it does:**

- **First command:** Gets the sequence number for the new transaction and stores it in `$seq` variable
- **Second command:** Lists current pending transactions
- **Third command:** Checks if the transaction can be executed (has enough approvals)

**Output:** Current transaction status and sequence number

---

### STEP 13: Approving and Executing Transaction

```bash
# Approve transaction
supra move multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number $seq \
    --profile accountA \
    --assume-yes

# Check execution status after approval
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:$seq

# Execute transaction
supra move multisig execute \
    --multisig-address $multisig_addr \
    --profile accountA \
    --max-gas 10000 \
    --assume-yes
```

**What it does:**

- **First command:** `accountA` approves the mint transaction
- **Second command:** Verifies the transaction now has enough signatures (2/3 required)
- **Third command:** Executes the approved transaction

**Output:** Mint function is executed, tokens are minted to the specified address

---

### STEP 14: Verifying Results

```bash
supra move tool view \
    --function-id $multisig_addr::FAA::balance_of \
    --args address:$accounta_addr
```

**What it does:**

- Calls the `balance_of` function to check token balance
- Verifies that `accountA` received the minted tokens
- Confirms the mint operation was successful

**Output:** Current token balance of `accountA` showing the newly minted tokens

## 🔄 Transaction Flow Summary

1. **Setup Phase:** Create accounts → Fund accounts → Create multisig
2. **Deployment Phase:** Build payload → Create transaction → Execute deployment
3. **Operation Phase:** Create function call → Approve transaction → Execute function
4. **Verification Phase:** Check results and balances

## 🔑 Key Concepts

- **Multisig Account:** Requires multiple signatures for transaction execution
- **Sequence Numbers:** Each transaction has a unique incrementing number
- **Pending Transactions:** Proposals waiting for sufficient approvals
- **Payload Files:** JSON files containing transaction data
- **Profile Management:** Different accounts with separate keys and permissions

## ⚠️ Important Notes

- Replace all placeholder addresses with actual values
- The multisig requires 2 out of 3 signatures to execute transactions
- Each step builds upon the previous ones - follow the sequence
- Save the multisig address from Step 5 for future use
- Test thoroughly on testnet before mainnet deployment
