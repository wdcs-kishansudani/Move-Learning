# SUPRA Multisig — Step‑by‑Step README

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Files](#files)
4. [Quick start — run the script](#quick-start--run-the-script)
5. [Step‑by‑step explanation (map to script)](#step-by-step-explanation-map-to-script)
6. [Environment variables & placeholders](#environment-variables--placeholders)
7. [Non-interactive / CI notes](#non-interactive--ci-notes)
8. [Troubleshooting & common errors](#troubleshooting--common-errors)
9. [Security & best practices](#security--best-practices)
10. [How to customize / extend this README](#how-to-customize--extend-this-readme)
11. [Changelog template](#changelog-template)

---

## Overview

This README documents a Bash script that automates creating owner profiles, funding them on the Supra Testnet, creating a multisig account (2-of-3 in the example), preparing a module publication payload, creating and approving multisig transactions, and executing them.

The script is interactive by default (prompts for addresses and reads user input). It prints colored status messages and uses the `supra` CLI and `jq` (for JSON parsing). Keep this README up to date as you extend the script.

---

## Prerequisites

- `supra` CLI installed and available in `$PATH`.
- `bash` (the script is a POSIX/Bash script).
- `jq` installed (used in the script to read JSON output for sequence numbers).
- Internet access to `https://rpc-testnet.supra.com` (or your chosen RPC).
- A workstation where running CLI commands with local keys is allowed and safe.
- suprascript : [multisig-example.sh](https://raw.githubusercontent.com/wdcs-kishansudani/Move-Learning/refs/heads/main/codes/Supra-Task-3/supra-multisig-setup.sh)

---

## Quick start — run the script

1. Make the script executable:

```bash
chmod +x multisig-example.sh
```

2. Run it (interactive):

```bash
./multisig-example.sh
```

The script will prompt for addresses (default, accountA, accountB, multisig_addr when required). Follow the prompts.

> Tip: keep a terminal log while running to capture the multisig address from the CLI output (you will need to paste it back into the prompt when requested).

---

## Step‑by‑step explanation (map to script)

Below each entry shows the exact command used by the script and a short explanation of what it does.

### STEP 1 — Creating owner accounts

Commands used:

```bash
supra profile new default --network testnet
supra profile new accountA --network testnet
supra profile new accountB --network testnet
```

What it does: Creates three local profiles (default, accountA, accountB) in the `supra` CLI keystore. You can also import existing private keys using `supra profile new <name> <PRIVATE_KEY> --network testnet`.

### STEP 2 — Activating default profile

Command used:

```bash
supra profile activate default
```

What it does: Sets the active profile to `default` for subsequent CLI commands that rely on the active profile.

### STEP 3 — Setting environment variables

The script prompts you to input three addresses:

- `default_addr` — address for the default profile
- `accounta_addr` — address for profile `accountA`
- `accountb_addr` — address for profile `accountB`

You can retrieve addresses with:

```bash
supra profile -l
```

(Use `supra profile -l -r` only if you explicitly need to view private keys — avoid doing this on shared machines.)

### STEP 4 — Funding owner accounts (Testnet faucet)

Commands used (per profile):

```bash
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile default
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountA
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountB
```

What it does: Requests testnet tokens for each profile so they have funds for gas.

### STEP 5 — Creating the multisig account

Command used (example in script):

```bash
supra move multisig create \
  --timeout-duration 3600 \
  --num-signatures-required 2 \
  --additional-owners $accounta_addr $accountb_addr \
  --rpc-url https://rpc-testnet.supra.com
```

What to capture: The `supra` CLI will print the multisig account address in its creation output. **Copy that address** and paste it when the script prompts for `multisig_addr`.

Notes on flags:

- `--timeout-duration`: how long proposals can wait before expiry (in seconds).
- `--num-signatures-required`: number of owner approvals required to execute a transaction.
- `--additional-owners`: list of the other owner addresses to add to the multisig.

### STEP 6 — Verifying multisig configuration

Commands used:

```bash
supra move tool view --function-id 0x1::multisig_account::num_signatures_required --args address:"$multisig_addr"
supra move tool view --function-id 0x1::multisig_account::owners --args address:"$multisig_addr"
supra move tool view --function-id 0x1::multisig_account::last_resolved_sequence_number --args address:"$multisig_addr"
```

What it does: Confirms the required signature count, owner list, and internal sequence number.

### STEP 7 — Preparing module deployment payload

Command used:

```bash
supra move tool build-publish-payload \
  --named-addresses my_addrx=$multisig_addr \
  --json-output-file publication.json \
  --assume-yes
```

What it does: Builds the `publication.json` payload used to publish a Move package (named addresses substituted with the multisig address). The file will be used to create a multisig proposal.

### STEP 8 — Creating the multisig publication transaction

Command used:

```bash
supra move multisig create-transaction \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --store-hash-only \
  --assume-yes
```

What it does: Submits a proposal into the multisig account for publishing a package (store the package hash on-chain).

### STEP 9 — Verifying the transaction

Commands used:

```bash
supra move tool view --function-id 0x1::multisig_account::get_pending_transactions --args address:"$multisig_addr"

supra move multisig verify-proposal \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --sequence-number 1

supra move tool view --function-id 0x1::multisig_account::can_be_executed --args address:"$multisig_addr" u64:1
```

What it does: Ensures the proposal is present and checks if the proposal currently has enough approvals to be executed.

### STEP 10 — Executing deployment

Command used:

```bash
supra move multisig execute-with-payload \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --profile accountA \
  --max-gas 10000 \
  --assume-yes
```

### Check if module exists

```bash
supra move tool list --account-address $multisig_addr --query modules
```

What it does: One owner (here `accountA`) triggers execution of the publication payload once approvals are met. CLI output will show transaction hash and status.

### STEP 11 — Creating function transactions (example mint)

Command used:

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

What it does: Creates a multisig proposal to call a contract function (an example `mint_to`). Adjust `function-id` and `args` to match your module.

### STEP 12 — Managing function execution

Get next sequence number used by the multisig (script uses `jq` to parse the result):

```bash
seq=$(supra move tool view \
  --function-id 0x1::multisig_account::next_sequence_number \
  --args address:"$multisig_addr" | jq -r .result[0])
```

Check pending transactions and whether the current sequence can be executed.

### STEP 13 — Approving and executing transaction

Commands used:

```bash
supra move multisig approve \
  --multisig-address $multisig_addr \
  --sequence-number $seq \
  --profile accountA \
  --assume-yes

supra move tool view --function-id 0x1::multisig_account::can_be_executed --args address:"$multisig_addr" u64:$seq

supra move multisig execute \
  --multisig-address $multisig_addr \
  --profile accountA \
  --max-gas 10000 \
  --assume-yes
```

What it does: Approve the pending proposal and execute it once the required approvals are met.

### STEP 14 — Verifying results

Command used (example to check balance):

```bash
supra move tool view \
  --function-id $multisig_addr::FAA::balance_of \
  --args address:$accounta_addr
```

What it does: Verifies the effect of the executed transaction (e.g., minted balance). Replace function and args suitable to your deployed module.

---

## Environment variables & placeholders

Placeholders used by the script and recommended names:

- `default_addr` — address for the `default` profile.
- `accounta_addr` — address for `accountA` profile.
- `accountb_addr` — address for `accountB` profile.
- `multisig_addr` — multisig account address returned at multisig creation.

Quick export example you can use before running a non-interactive version:

```bash
export DEFAULT_ADDR=0x1111...   # default profile address
export ACCOUNTA_ADDR=0x2222...  # accountA address
export ACCOUNTB_ADDR=0x3333...  # accountB address
export MULTISIG_ADDR=0xAAA...   # multisig address
```

> Note: The provided script reads addresses from `read` prompts. If you prefer CI / non-interactive runs, populate these variables and remove or comment out `read` lines in the script.

---

## Non-interactive / CI notes

- The script uses interactive `read` prompts. In CI you should:

  1. Export required environment variables before running.
  2. Replace `read` blocks with variable references or pass arguments to the script.
  3. Remove colored output if your CI log doesn’t support ANSI colors.

- Example of converting a prompt into a non-interactive variable usage:

```bash
# original interactive
read multisig_addr

# CI version (multisig_addr provided by env)
multisig_addr=${MULTISIG_ADDR}
```

- Ensure private keys and profiles used by CI are stored securely as CI secrets.
