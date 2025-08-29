# Multisign Loyalty Reward

### Creating Owner Accounts

```bash
aptos key generate --vanity-prefix 0xaaa --output-file aaa.key

aptos key generate --vanity-prefix 0xbbb --output-file bbb.key

aptos key generate --vanity-prefix 0xccc --output-file ccc.key
```

### Save theaddress in an environment variable for easy reference

```bash
aaa_addr=0xaaa8feba6330a3d1d284f63f45d5bcdfe3f98fcedc227fd6ced65aa20c08f3d0
bbb_addr=0xbbb448ca1e2e47e7ed2ac4e0017267c6ad1d68aa12d48ca5dfc5aeebf8827316
ccc_addr=0xccc1454c4a226a8219f7be8b1ed50675f7ffcfd3597973c655d89dd17983ca8e
```

### Funding Owner Accounts

```bash
aptos account fund-with-faucet --account $aaa_addr
aptos account fund-with-faucet --account $bbb_addr
aptos account fund-with-faucet --account $ccc_addr
```

### Creating the Multisig Account

```bash
aptos multisig create \
  --additional-owners $bbb_addr \
  --additional-owners $ccc_addr \
  --num-signatures-required 2 \
  --private-key-file aaa.key \
  --assume-yes
```

### Save the multisig address in an environment variable for easy reference

```bash
multisig_addr=0xc32bea51fb28a870689ed170fb79664686e78b55dec400b10352996934750f59
```

### Funding the Multisig Account

```bash
aptos account fund-with-faucet --account $multisig_addr
```

### Verifying the Multisig Configuration

```bash
aptos move view \
    --function-id 0x1::multisig_account::num_signatures_required \
    --args address:"$multisig_addr"
```

### Verifying Owners

```bash
aptos move view \
    --function-id 0x1::multisig_account::owners \
    --args address:"$multisig_addr"
```

### Checking Transaction Sequence Number

```bash
aptos move view \
    --function-id 0x1::multisig_account::last_resolved_sequence_number \
    --args address:"$multisig_addr"
```

### Generate publication payload JSON file

```bash
aptos move build-publish-payload \
  --named-addresses my_addrx=0xc32bea51fb28a870689ed170fb79664686e78b55dec400b10352996934750f59 \
  --json-output-file publication.json \
  --assume-yes

```

### Create Multisig Publication Transaction

Option 1: Store Hash Only (Recommended for large packages)

```bash
aptos multisig create-transaction \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --store-hash-only \
  --private-key-file aaa.key \
  --assume-yes
```

Option 2: Store Full Payload (For smaller packages)

```bash
aptos multisig create-transaction \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --private-key-file aaa.key \
  --assume-yes
```

### Verify Transaction

- Check pending transactions:

```bash
aptos move view \
  --function-id 0x1::multisig_account::get_pending_transactions \
  --args address:"$multisig_addr"
```

- Note the sequence number (usually starts at 1).

### Collect Approvals

- Owner 1 (already approved by creating transaction)

- Owner 2 Must Approve

```bash
# Verify the proposal first (optional but recommended)
aptos multisig verify-proposal \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --sequence-number 1

# Approve the transaction
aptos multisig approve \
  --multisig-address $multisig_addr \
  --sequence-number 1 \
  --private-key-file bbb.key \
  --assume-yes
```

### Execute the Transaction

- Check if ready to execute

```bash
aptos move view \
  --function-id 0x1::multisig_account::can_be_executed \
  --args address:"$multisig_addr" u64:1
```

### Execute the deployment:

- If you used --store-hash-only:

```bash
aptos multisig execute-with-payload \
  --multisig-address $multisig_addr \
  --json-file publication.json \
  --private-key-file aaa.key \
  --max-gas 10000 \
  --assume-yes
```

- If you stored full payload:

```bash
aptos multisig execute \
  --multisig-address $multisig_addr \
  --sequence-number 1 \
  --private-key-file aaa.key \
  --max-gas 10000 \
  --assume-yes
```

### Verify Deployment

```bash
# Check if module exists
aptos account list --account $multisig_addr

# Test a view function if you have one
aptos move view \
  --function-id $multisig_addr::your_module::your_view_function
```

### Invoke write TX

```bash
aptos multisig create-transaction \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FA::mint_to \
    --type-args \
        0x1::account::Account \
        0x1::chain_id::ChainId \
    --args \
        address:$bbb_addr \
        u64:10 \
        u64:999999999 \
    --private-key-file bbb.key \
    --assume-yes
```

### Note the next sequence number has been incremented again

```bash
aptos move view \
    --function-id 0x1::multisig_account::next_sequence_number \
    --args \
        address:"$multisig_addr"
```

### Now both the publication and parameter transactions are pending:

```bash
aptos move view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args \
        address:"$multisig_addr"
```

### Check can be executed

```bash
aptos move view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args \
        address:"$multisig_addr" \
        u64:2
```

### Aprove from second owner

```bash
aptos multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number 2 \
    --private-key-file bbb.key \
    --assume-yes
```

### Check can be executed

```bash
aptos move view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args \
        address:"$multisig_addr" \
        u64:2
```

### Now either aaa or bbb can invoke the publication transaction from the multisig account, passing the full transaction payload since only the hash was stored on-chain:

```bash
aptos multisig execute-with-payload \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FA::mint_to \
    --type-args \
        0x1::account::Account \
        0x1::chain_id::ChainId \
    --args \
        address:$bbb_addr \
        u64:10 \
        u64:999999999 \
    --private-key-file bbb.key \
    --max-gas 10000 \
    --assume-yes
```

### Since only bbb has voted on the governance parameter transaction (which she implicitly approved upon proposing), the transaction can’t be executed yet:

```bash
aptos move view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args \
        address:"$multisig_addr" \
        u64:2
```

### payload stored on-chain matches the function arguments

```bash
aptos multisig verify-proposal \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FA::mint_to \
    --type-args \
        0x1::account::Account \
        0x1::chain_id::ChainId \
    --args \
        address:"$bbb_addr" \
        u64:10 \
        u64:999999999 \
    --sequence-number 2
```

- Note that the verification fails if he modifies even a single argument:

### aaa approves the transaction:
```bash
aptos multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number 2 \
    --private-key-file aaa.key \
    --assume-yes
```

### Since the payload was stored on-chain, it is not required to execute the pending transaction:
```bash
aptos multisig execute \
    --multisig-address $multisig_addr \
    --private-key-file aaa.key \
    --max-gas 10000 \
    --assume-yes
```

## Complete Example Workflow

```bash
# 1. Set up accounts and addresses
owner1_addr=0xace...
owner2_addr=0xbee...

# 2. Create multisig
aptos multisig create --additional-owners $owner2_addr --num-signatures-required 2 --private-key-file owner1.key --assume-yes

# 3. Store multisig address
multisig_addr=0x57478da... # from previous output

# 4. Generate publication payload
aptos move build-publish-payload --named-addresses your_module=$multisig_addr --json-output-file publication.json --assume-yes

# 5. Create transaction
aptos multisig create-transaction --multisig-address $multisig_addr --json-file publication.json --store-hash-only --private-key-file owner1.key --assume-yes

# 6. Second owner approves
aptos multisig approve --multisig-address $multisig_addr --sequence-number 1 --private-key-file owner2.key --assume-yes

# 7. Execute deployment
aptos multisig execute-with-payload --multisig-address $multisig_addr --json-file publication.json --private-key-file owner1.key --max-gas 10000 --assume-yes
```

### Ref: [Ref](https://dev.to/gunaseelan25/setting-up-an-aptos-multisig-account-a-step-by-step-guide-4nh0)
