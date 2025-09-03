# Complete Technical Guide: Aptos Move Fungible Assets (FA)

## Table of Contents

1. [Introduction & Architecture Overview](#introduction--architecture-overview)
2. [Core Components Deep Dive](#core-components-deep-dive)
3. [Technical Implementation](#technical-implementation)
4. [Step-by-Step Development Guide](#step-by-step-development-guide)
5. [Advanced Features](#advanced-features)
6. [Security Considerations](#security-considerations)
7. [Migration from Coin Standard](#migration-from-coin-standard)
8. [Best Practices & Examples](#best-practices--examples)

---

## 1. Introduction & Architecture Overview

### What are Fungible Assets?

The Aptos Fungible Asset Standard (also known as "Fungible Asset" or "FA") provides a standard, type-safe way to define fungible assets in the Move ecosystem. It is a modern replacement for the coin module that allows for seamless minting, transfer, and customization of fungible assets.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FUNGIBLE ASSET ECOSYSTEM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐          ┌─────────────────────────────┐   │
│  │ Object<Metadata>│◄─────────┤      Asset Creator          │   │
│  │                 │          │   (Owns the metadata)       │   │
│  │ • Name          │          └─────────────────────────────┘   │
│  │ • Symbol        │                                            │
│  │ • Decimals      │                                            │
│  │ • Icon URI      │                                            │
│  │ • Project URI   │                                            │
│  │ • Supply Info   │                                            │
│  └─────────┬───────┘                                            │
│            │                                                    │
│            │ References                                         │
│            │                                                    │
│  ┌─────────▼───────┐          ┌─────────────────────────────┐   │
│  │Object<FungibleStore>│◄─────┤        Account A            │   │
│  │                 │          │   (Owns fungible store)     │   │
│  │ • Balance: 100  │          └─────────────────────────────┘   │
│  │ • Frozen: false │                                            │
│  └─────────────────┘                                            │
│                                                                 │
│  ┌─────────────────┐          ┌─────────────────────────────┐   │
│  │Object<FungibleStore>│◄─────┤        Account B            │   │
│  │                 │          │   (Owns fungible store)     │   │
│  │ • Balance: 50   │          └─────────────────────────────┘   │
│  │ • Frozen: false │                                            │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Key Advantages over Legacy Coin Standard

1. **Object-based Architecture**: More flexible and extensible
2. **Automatic Store Management**: No need for manual CoinStore registration
3. **Enhanced Customization**: Support for custom logic via dispatchable hooks
4. **Better Composability**: Objects can own multiple resources
5. **Deterministic Addressing**: Primary stores have predictable addresses

---

## 2. Core Components Deep Dive

### 2.1 Object<Metadata>

The Metadata object contains all the descriptive information about the fungible asset:

```move
struct Metadata has key {
    name: String,
    symbol: String,
    decimals: u8,
    icon_uri: String,
    project_uri: String,
    // Additional fields for supply management, etc.
}
```

**Key Characteristics:**

- **Owned by Asset Creator**: The entity that creates the FA owns this object
- **Immutable Reference**: Once created, serves as the permanent identifier for the FA type
- **Non-deletable**: Cannot be destroyed while active balances exist
- **Global Identifier**: All fungible stores reference this metadata object

### 2.2 Object<FungibleStore>

Each account that holds the fungible asset has a FungibleStore object:

```move
struct FungibleStore has key {
    metadata: Object<Metadata>,  // References the FA type
    balance: u64,                // Current balance
    frozen: bool,                // Whether transfers are frozen
}
```

**Two Types of Fungible Stores:**

#### Primary Fungible Store

- **One per account per FA type**: Each account has exactly one primary store for each FA
- **Deterministic Address**: Address calculated using the formula:
  ```
  sha3_256(32-byte account address | 32-byte metadata object address | 0xFC)
  ```
- **Auto-creation**: Created automatically when FA is deposited
- **Non-deletable**: Cannot be removed, only emptied

#### Secondary Fungible Store

- **Multiple per account**: Accounts can have multiple secondary stores
- **Custom addressing**: Not deterministically derived
- **Deletable**: Can be destroyed when empty
- **Advanced use cases**: Primarily for DeFi applications and smart contracts

### 2.3 Reference System (Refs)

The FA standard uses a sophisticated permission system through "Refs":

```
┌─────────────────┐    generates    ┌─────────────────┐
│ ConstructorRef  │────────────────►│    MintRef      │
│                 │                 │ (mint tokens)   │
│ (initial setup) │                 └─────────────────┘
│                 │
│                 │    generates    ┌─────────────────┐
│                 │────────────────►│   TransferRef   │
│                 │                 │ (freeze/unfreeze│
│                 │                 │  force transfer)│
│                 │                 └─────────────────┘
│                 │
│                 │    generates    ┌─────────────────┐
│                 └────────────────►│    BurnRef      │
│                                   │ (burn tokens)   │
│                                   └─────────────────┘
```

**MintRef**:

- Allows creating new tokens
- Can mint to any account
- Holder controls token supply expansion

**TransferRef**:

- Can freeze/unfreeze accounts
- Can force transfers (bypass frozen state)
- Essential for regulatory compliance

**BurnRef**:

- Allows destroying tokens
- Can burn from any account (with proper permissions)
- Reduces total supply

---

## 3. Technical Implementation

### 3.1 Address Derivation Mechanics

**Primary Store Address Calculation:**

```move
// Pseudocode for primary store address derivation
fun derive_primary_store_address(
    owner_address: address,
    metadata_address: address
): address {
    let seed = owner_address + metadata_address + 0xFC;
    sha3_256(seed)
}
```

**Why this matters:**

- **Predictable**: You can calculate the store address without querying the blockchain
- **Unique**: Each combination of (owner, metadata) has exactly one primary store
- **Efficient**: No need to search or index store addresses

### 3.2 Event System Architecture

```
                    Transfer Operation
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │ Withdraw    │ │   Update    │ │  Deposit    │
    │   Event     │ │  Balances   │ │   Event     │
    └─────────────┘ └─────────────┘ └─────────────┘

    From Store         In Memory         To Store
```

**Event Types:**

1. **Deposit Event**: Triggered when FA enters a store
2. **Withdraw Event**: Triggered when FA leaves a store
3. **Frozen Event**: Triggered when freeze status changes

### 3.3 Memory Layout

```
Account Address: 0xABC123...
├── Regular Resources
├── Objects Owned:
│   ├── Primary FA Store #1 (TokenX) → Balance: 1000
│   ├── Primary FA Store #2 (TokenY) → Balance: 500
│   └── Secondary FA Store #3 (TokenX) → Balance: 200
└── Other Objects...

Asset Creator Address: 0xDEF456...
├── Objects Owned:
│   ├── Metadata Object (TokenX)
│   │   ├── Name: "MyToken"
│   │   ├── Symbol: "MTK"
│   │   └── Decimals: 8
│   └── Permission Refs (MintRef, BurnRef, etc.)
```

---

## 4. Step-by-Step Development Guide

### Step 1: Set Up Your Module Structure

```move
module my_address::my_fungible_asset {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::option::{Self, Option};

    /// Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_FROZEN: u64 = 3;

    /// Asset configuration
    const ASSET_SYMBOL: vector<u8> = b"MFA";

    /// Capabilities storage
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }
}
```

### Step 2: Create the Fungible Asset

```move
/// Initialize the fungible asset
public entry fun initialize(admin: &signer) {
    // Create a named object for deterministic addressing
    let constructor_ref = object::create_named_object(admin, ASSET_SYMBOL);

    // Create the fungible asset with metadata
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        &constructor_ref,
        option::none(),                              // No maximum supply
        string::utf8(b"My Fungible Asset"),         // Name
        string::utf8(ASSET_SYMBOL),                 // Symbol
        8,                                          // Decimals
        string::utf8(b"https://mysite.com/icon.png"), // Icon URI
        string::utf8(b"https://mysite.com"),        // Project URI
    );

    // Generate the capability refs
    let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

    // Store the capabilities
    let metadata_signer = object::generate_signer(&constructor_ref);
    move_to(&metadata_signer, ManagedFungibleAsset {
        mint_ref,
        transfer_ref,
        burn_ref,
    });
}
```

### Step 3: Implement Core Operations

```move
/// Mint tokens to a recipient
public entry fun mint(
    admin: &signer,
    recipient: address,
    amount: u64,
) acquires ManagedFungibleAsset {
    let asset = get_metadata();
    let managed_fungible_asset = authorized_borrow_refs(admin, asset);

    // Mint the fungible asset
    let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);

    // Deposit to recipient
    primary_fungible_store::deposit(recipient, fa);
}

/// Transfer tokens between accounts
public entry fun transfer(
    from: &signer,
    to: address,
    amount: u64,
) {
    let asset = get_metadata();
    primary_fungible_store::transfer(from, asset, to, amount);
}

/// Burn tokens from an account
public entry fun burn(
    admin: &signer,
    from: address,
    amount: u64,
) acquires ManagedFungibleAsset {
    let asset = get_metadata();
    let managed_fungible_asset = authorized_borrow_refs(admin, asset);

    // Withdraw from the account
    let fa = primary_fungible_store::withdraw_with_ref(
        &managed_fungible_asset.transfer_ref,
        from,
        amount
    );

    // Burn the withdrawn assets
    fungible_asset::burn(&managed_fungible_asset.burn_ref, fa);
}
```

### Step 4: Add Utility Functions

```move
/// Get the metadata object
#[view]
public fun get_metadata(): Object<Metadata> {
    let asset_address = object::create_object_address(&@my_address, ASSET_SYMBOL);
    object::address_to_object<Metadata>(asset_address)
}

/// Check balance of an account
#[view]
public fun balance(account: address): u64 {
    let asset = get_metadata();
    primary_fungible_store::balance(account, asset)
}

/// Check if an account is frozen
#[view]
public fun is_frozen(account: address): bool {
    let asset = get_metadata();
    primary_fungible_store::is_frozen(account, asset)
}

/// Internal function to verify admin and get refs
fun authorized_borrow_refs(
    admin: &signer,
    asset: Object<Metadata>,
): &ManagedFungibleAsset acquires ManagedFungibleAsset {
    assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(E_NOT_OWNER));
    borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
}
```

---

## 5. Advanced Features

### 5.1 Dispatchable Fungible Assets (DFA)

DFA allows you to embed custom logic that executes automatically during transfers:

```move
module my_address::yield_bearing_token {
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::function_info;

    /// Custom deposit hook that accrues yield
    public fun deposit_with_yield<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) {
        // Calculate and add yield before deposit
        let yield_amount = calculate_yield(store);
        let yield_fa = mint_yield(yield_amount);

        // Combine original + yield
        fungible_asset::merge(&mut fa, yield_fa);

        // Perform the actual deposit
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    /// Register the custom hook
    fun register_hooks(constructor_ref: &ConstructorRef) {
        let deposit_function = function_info::new_function_info(
            &module_signer,
            string::utf8(b"yield_bearing_token"),
            string::utf8(b"deposit_with_yield")
        );

        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::none(), // no custom withdraw
            option::some(deposit_function),
            option::none()  // no custom derived balance
        );
    }
}
```

### 5.2 Secondary Store Management

```move
/// Create a secondary store for advanced DeFi operations
public fun create_secondary_store(
    owner: &signer,
    metadata: Object<Metadata>
): Object<FungibleStore> {
    // Create a new object to own the store
    let constructor_ref = object::create_object(signer::address_of(owner));

    // Create the secondary store
    let store = fungible_asset::create_store(&constructor_ref, metadata);

    store
}

/// Transfer between stores within the same account
public fun internal_transfer(
    owner: &signer,
    from_store: Object<FungibleStore>,
    to_store: Object<FungibleStore>,
    amount: u64,
) {
    // Verify ownership of both stores
    assert!(object::is_owner(from_store, signer::address_of(owner)), E_NOT_OWNER);
    assert!(object::is_owner(to_store, signer::address_of(owner)), E_NOT_OWNER);

    // Perform the transfer
    let fa = fungible_asset::withdraw(owner, from_store, amount);
    fungible_asset::deposit(to_store, fa);
}
```

---

## 6. Security Considerations

### 6.1 Access Control

```move
/// Implement role-based access control
struct Roles has key {
    admin: address,
    minters: vector<address>,
    burners: vector<address>,
}

/// Check if address has minting rights
fun can_mint(addr: address): bool acquires Roles {
    let roles = borrow_global<Roles>(get_metadata_address());
    addr == roles.admin || vector::contains(&roles.minters, &addr)
}

/// Secure mint function with role checking
public entry fun secure_mint(
    caller: &signer,
    to: address,
    amount: u64,
) acquires ManagedFungibleAsset, Roles {
    let caller_addr = signer::address_of(caller);
    assert!(can_mint(caller_addr), error::permission_denied(E_NOT_AUTHORIZED));

    // Proceed with minting...
}
```

### 6.2 Reentrancy Protection

```move
/// Reentrancy guard
struct ReentrancyGuard has key {
    locked: bool,
}

/// Modifier to prevent reentrancy
fun with_reentrancy_guard<T>(f: |&mut ReentrancyGuard| T): T acquires ReentrancyGuard {
    let guard = borrow_global_mut<ReentrancyGuard>(get_metadata_address());
    assert!(!guard.locked, error::invalid_state(E_REENTRANCY));

    guard.locked = true;
    let result = f(guard);
    guard.locked = false;

    result
}
```

### 6.3 Pause Mechanism

```move
/// Emergency pause functionality
struct PauseState has key {
    paused: bool,
    pauser: address,
}

/// Pause all operations
public entry fun pause(pauser: &signer) acquires PauseState {
    let pause_state = borrow_global_mut<PauseState>(get_metadata_address());
    assert!(signer::address_of(pauser) == pause_state.pauser, E_NOT_AUTHORIZED);
    pause_state.paused = true;
}

/// Check if operations are paused
fun ensure_not_paused() acquires PauseState {
    let pause_state = borrow_global<PauseState>(get_metadata_address());
    assert!(!pause_state.paused, error::invalid_state(E_PAUSED));
}
```

---

## 7. Migration from Coin Standard

### 7.1 Understanding the Migration

Projects utilizing the coin module do not need to modify their contracts. The coin module has been enhanced to handle migration automatically.

**Migration Process:**

1. **Automatic Pairing**: Each Coin type gets a corresponding FA
2. **Transparent Operations**: Coin operations work seamlessly with FA
3. **Balance Aggregation**: Total balance = Coin balance + FA balance
4. **Event Compatibility**: Both Coin and FA events may be emitted

### 7.2 Migration Timeline

- **June 23-30, 2025**: All tokens except APT migrate
- **June 30 - July 8, 2025**: APT migration period
- **Post-migration**: Coin API continues working but routes to FA

### 7.3 Developer Migration Checklist

```move
// OLD: Coin-based implementation
module old_coin::my_coin {
    use aptos_framework::coin;

    struct MyCoin has key {}

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        coin::transfer<MyCoin>(from, to, amount);
    }
}

// NEW: FA-based implementation (recommended)
module new_fa::my_asset {
    use aptos_framework::primary_fungible_store;

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        let metadata = get_metadata();
        primary_fungible_store::transfer(from, metadata, to, amount);
    }
}
```

**Key Changes:**

1. **Balance Queries**: Use FA balance APIs instead of resource queries
2. **Event Handling**: Listen for both Coin and FA events
3. **Address Calculation**: Use deterministic FA store addresses
4. **New Features**: Leverage FA-specific capabilities

---

## 8. Best Practices & Examples

### 8.1 Production-Ready Token Template

```move
module production::professional_token {
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object;
    use aptos_framework::event;
    use std::string;
    use std::option;
    use std::signer;
    use std::error;

    /// Comprehensive capability management
    struct TokenCapabilities has key {
        mint_ref: fungible_asset::MintRef,
        transfer_ref: fungible_asset::TransferRef,
        burn_ref: fungible_asset::BurnRef,
        extend_ref: object::ExtendRef,
    }

    /// Advanced configuration
    struct TokenConfig has key {
        max_supply: option::Option<u128>,
        mint_enabled: bool,
        transfer_enabled: bool,
        burn_enabled: bool,
        upgrade_enabled: bool,
    }

    /// Governance and roles
    struct TokenGovernance has key {
        admin: address,
        pending_admin: option::Option<address>,
        minters: vector<address>,
        pausers: vector<address>,
    }

    /// Events for monitoring
    #[event]
    struct MintEvent has drop, store {
        recipient: address,
        amount: u64,
        total_supply: u128,
    }

    #[event]
    struct BurnEvent has drop, store {
        account: address,
        amount: u64,
        total_supply: u128,
    }

    /// Initialize with comprehensive setup
    public entry fun initialize_professional_token(
        admin: &signer,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        max_supply: option::Option<u128>,
    ) {
        let constructor_ref = object::create_named_object(admin, *string::bytes(&symbol));

        // Create the fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            max_supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
        );

        // Generate all capability refs
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        // Set up the token
        let token_signer = object::generate_signer(&constructor_ref);
        let admin_address = signer::address_of(admin);

        move_to(&token_signer, TokenCapabilities {
            mint_ref,
            transfer_ref,
            burn_ref,
            extend_ref,
        });

        move_to(&token_signer, TokenConfig {
            max_supply,
            mint_enabled: true,
            transfer_enabled: true,
            burn_enabled: true,
            upgrade_enabled: true,
        });

        move_to(&token_signer, TokenGovernance {
            admin: admin_address,
            pending_admin: option::none(),
            minters: vector[admin_address],
            pausers: vector[admin_address],
        });
    }

    /// Professional minting with comprehensive checks
    public entry fun mint_professional(
        caller: &signer,
        recipient: address,
        amount: u64,
    ) acquires TokenCapabilities, TokenConfig, TokenGovernance {
        let metadata = get_metadata();
        let caller_address = signer::address_of(caller);

        // Access control
        let governance = borrow_global<TokenGovernance>(object::object_address(&metadata));
        assert!(
            vector::contains(&governance.minters, &caller_address),
            error::permission_denied(E_NOT_MINTER)
        );

        // Configuration checks
        let config = borrow_global<TokenConfig>(object::object_address(&metadata));
        assert!(config.mint_enabled, error::invalid_state(E_MINT_DISABLED));

        // Supply cap check
        if (option::is_some(&config.max_supply)) {
            let current_supply = fungible_asset::supply(metadata);
            let max_supply = *option::borrow(&config.max_supply);
            assert!(
                option::is_some(&current_supply) &&
                *option::borrow(&current_supply) + (amount as u128) <= max_supply,
                error::invalid_argument(E_EXCEEDS_MAX_SUPPLY)
            );
        };

        // Perform mint
        let capabilities = borrow_global<TokenCapabilities>(object::object_address(&metadata));
        let fa = fungible_asset::mint(&capabilities.mint_ref, amount);
        primary_fungible_store::deposit(recipient, fa);

        // Emit event
        let new_supply = fungible_asset::supply(metadata);
        event::emit(MintEvent {
            recipient,
            amount,
            total_supply: *option::borrow(&new_supply),
        });
    }
}
```

### 8.2 Error Handling Best Practices

```move
/// Comprehensive error codes
const E_NOT_AUTHORIZED: u64 = 1;
const E_INSUFFICIENT_BALANCE: u64 = 2;
const E_FROZEN_ACCOUNT: u64 = 3;
const E_EXCEEDS_MAX_SUPPLY: u64 = 4;
const E_MINT_DISABLED: u64 = 5;
const E_BURN_DISABLED: u64 = 6;
const E_TRANSFER_DISABLED: u64 = 7;
const E_PAUSED: u64 = 8;
const E_INVALID_AMOUNT: u64 = 9;
const E_REENTRANCY: u64 = 10;

/// Safe arithmetic operations
fun safe_add(a: u64, b: u64): u64 {
    assert!(a <= MAX_U64 - b, error::invalid_argument(E_OVERFLOW));
    a + b
}

fun safe_sub(a: u64, b: u64): u64 {
    assert!(a >= b, error::invalid_argument(E_UNDERFLOW));
    a - b
}
```

### 8.3 Testing Framework

```move
#[test_only]
module professional::token_tests {
    use professional::professional_token;
    use aptos_framework::account;
    use std::string;
    use std::option;

    #[test(admin = @0x123, user = @0x456)]
    public fun test_complete_workflow(
        admin: &signer,
        user: &signer,
    ) {
        // Initialize
        professional_token::initialize_professional_token(
            admin,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            8,
            string::utf8(b""),
            string::utf8(b""),
            option::some(1000000u128),
        );

        // Test minting
        professional_token::mint_professional(
            admin,
            signer::address_of(user),
            1000,
        );

        // Verify balance
        assert!(professional_token::balance(signer::address_of(user)) == 1000, 1);

        // Test transfer
        let recipient = @0x789;
        professional_token::transfer(user, recipient, 100);

        // Verify balances after transfer
        assert!(professional_token::balance(signer::address_of(user)) == 900, 2);
        assert!(professional_token::balance(recipient) == 100, 3);
    }
}
```

---

## Conclusion

The Aptos Fungible Asset standard represents a significant advancement in blockchain token architecture. By leveraging Move Objects, it provides enhanced flexibility, automatic management, and powerful customization capabilities while maintaining security and efficiency.

Key takeaways:

1. **Object-based Design**: More flexible than traditional resource-based tokens
2. **Automatic Management**: Eliminates manual store registration complexity
3. **Rich Customization**: Dispatchable hooks enable sophisticated token behavior
4. **Seamless Migration**: Backward compatibility with existing Coin-based systems
5. **Enterprise Ready**: Built-in compliance features and governance capabilities

This comprehensive guide provides you with the technical foundation to build sophisticated fungible assets on Aptos. The FA standard's object-based architecture, combined with Move's type safety and formal verification capabilities, makes it an ideal platform for both simple tokens and complex financial instruments.

---

## Appendix A: Quick Reference

### Essential Functions

#### Asset Creation

```move
// Create the fungible asset
primary_fungible_store::create_primary_store_enabled_fungible_asset(
    constructor_ref: &ConstructorRef,
    maximum_supply: Option<u128>,
    name: String,
    symbol: String,
    decimals: u8,
    icon_uri: String,
    project_uri: String,
)

// Generate capability refs
fungible_asset::generate_mint_ref(constructor_ref: &ConstructorRef): MintRef
fungible_asset::generate_transfer_ref(constructor_ref: &ConstructorRef): TransferRef
fungible_asset::generate_burn_ref(constructor_ref: &ConstructorRef): BurnRef
```

#### Core Operations

```move
// Minting
fungible_asset::mint(mint_ref: &MintRef, amount: u64): FungibleAsset
fungible_asset::mint_to(mint_ref: &MintRef, store: Object<FungibleStore>, amount: u64)

// Transferring
primary_fungible_store::transfer<T: key>(
    sender: &signer,
    metadata: Object<T>,
    recipient: address,
    amount: u64
)

// Burning
fungible_asset::burn(burn_ref: &BurnRef, fa: FungibleAsset)
fungible_asset::burn_from(
    burn_ref: &BurnRef,
    store: Object<FungibleStore>,
    amount: u64
)

// Balance queries
primary_fungible_store::balance<T: key>(account: address, metadata: Object<T>): u64
```

#### Advanced Store Management

```move
// Primary store operations
primary_fungible_store::primary_store<T: key>(
    owner: address,
    metadata: Object<T>
): Object<FungibleStore>

primary_fungible_store::create_primary_store<T: key>(
    owner_addr: address,
    metadata: Object<T>
): Object<FungibleStore>

// Secondary store operations
fungible_asset::create_store<T: key>(
    constructor_ref: &ConstructorRef,
    metadata: Object<T>
): Object<FungibleStore>
```

### Common Patterns

#### Pattern 1: Simple Token

```move
module simple::basic_token {
    struct TokenRefs has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
    }

    public entry fun init(creator: &signer) {
        let constructor_ref = object::create_named_object(creator, b"BASIC");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::some(1000000u128), // 1M max supply
            string::utf8(b"Basic Token"),
            string::utf8(b"BASIC"),
            6,
            string::utf8(b""),
            string::utf8(b""),
        );

        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        move_to(&object::generate_signer(&constructor_ref), TokenRefs {
            mint_ref,
            burn_ref,
        });
    }
}
```

#### Pattern 2: Governance Token

```move
module governance::gov_token {
    struct GovernanceCapability has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        voting_power_multiplier: u64,
    }

    struct VotingRecord has key {
        total_votes_cast: u64,
        proposals_participated: vector<u64>,
    }

    public entry fun delegate_voting_power(
        delegator: &signer,
        delegate: address,
        amount: u64,
    ) acquires GovernanceCapability {
        // Implementation for vote delegation
        let metadata = get_metadata();
        let gov_cap = borrow_global<GovernanceCapability>(object::object_address(&metadata));

        // Create a secondary store for delegated tokens
        // Transfer tokens to escrow with delegation metadata
    }
}
```

#### Pattern 3: Yield-Bearing Token

```move
module defi::yield_token {
    use aptos_framework::timestamp;
    use aptos_framework::dispatchable_fungible_asset;

    struct YieldConfig has key {
        annual_rate: u64,  // Basis points (10000 = 100%)
        last_update: u64,
        accumulated_yield_per_token: u128,
    }

    public fun deposit_with_yield_calculation<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) acquires YieldConfig {
        let config = borrow_global_mut<YieldConfig>(object::object_address(&store));
        let current_time = timestamp::now_seconds();

        if (config.last_update < current_time) {
            let time_elapsed = current_time - config.last_update;
            let yield_rate = (config.annual_rate * time_elapsed) / (365 * 24 * 60 * 60 * 10000);
            config.accumulated_yield_per_token = config.accumulated_yield_per_token + (yield_rate as u128);
            config.last_update = current_time;
        };

        // Calculate and mint yield before deposit
        let current_balance = fungible_asset::store_balance(store);
        let yield_amount = ((current_balance as u128) * config.accumulated_yield_per_token / 1000000u128) as u64;

        if (yield_amount > 0) {
            // Would need mint_ref access here - simplified for example
            let yield_fa = mint_yield_tokens(yield_amount);
            fungible_asset::merge(&mut fa, yield_fa);
        };

        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }
}
```

---

## Appendix B: Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: "Object not found" Error

```move
// Problem: Trying to access metadata object that doesn't exist
let metadata = object::address_to_object<Metadata>(wrong_address);

// Solution: Use proper address derivation
let metadata_address = object::create_object_address(&@creator_address, SYMBOL);
let metadata = object::address_to_object<Metadata>(metadata_address);
```

#### Issue 2: Permission Denied on Mint/Burn

```move
// Problem: Trying to use capabilities without proper ownership
public entry fun mint(caller: &signer, amount: u64) {
    let mint_ref = borrow_global<MintRef>(some_address); // Wrong!
    // ...
}

// Solution: Proper capability management
public entry fun mint(admin: &signer, recipient: address, amount: u64)
acquires TokenCapabilities {
    let metadata = get_metadata();
    let capabilities = authorized_borrow_refs(admin, metadata);
    let fa = fungible_asset::mint(&capabilities.mint_ref, amount);
    primary_fungible_store::deposit(recipient, fa);
}
```

#### Issue 3: Store Address Calculation Issues

```move
// Problem: Manual address calculation errors
let wrong_store_addr = @0x123; // Hardcoded wrong

// Solution: Use framework functions
let store = primary_fungible_store::primary_store(owner_addr, metadata);
// Or if you need the address specifically:
let store_addr = object::object_address(&store);
```

#### Issue 4: Event Handling in Migration

```move
// Problem: Only listening for old coin events
event::on<coin::WithdrawEvent>(...); // Incomplete

// Solution: Listen for both event types
event::on<coin::WithdrawEvent>(...);
event::on<fungible_asset::WithdrawEvent>(...);
```

### Performance Optimization Tips

#### Tip 1: Batch Operations

```move
// Instead of multiple individual operations
public entry fun inefficient_multi_mint(
    admin: &signer,
    recipients: vector<address>,
    amounts: vector<u64>,
) {
    let i = 0;
    while (i < vector::length(&recipients)) {
        mint(admin, *vector::borrow(&recipients, i), *vector::borrow(&amounts, i));
        i = i + 1;
    };
}

// Use batch operations
public entry fun batch_mint(
    admin: &signer,
    recipients: vector<address>,
    amounts: vector<u64>,
) acquires TokenCapabilities {
    let metadata = get_metadata();
    let capabilities = authorized_borrow_refs(admin, metadata);

    let i = 0;
    while (i < vector::length(&recipients)) {
        let fa = fungible_asset::mint(&capabilities.mint_ref, *vector::borrow(&amounts, i));
        primary_fungible_store::deposit(*vector::borrow(&recipients, i), fa);
        i = i + 1;
    };
}
```

#### Tip 2: Minimize Global State Access

```move
// Less efficient: Multiple global accesses
public fun inefficient_operation() acquires Config {
    if (borrow_global<Config>(@addr).paused) return;
    if (borrow_global<Config>(@addr).mint_enabled) {
        // do something with borrow_global<Config>(@addr).max_supply
    };
}

// More efficient: Single access with local reference
public fun efficient_operation() acquires Config {
    let config = borrow_global<Config>(@addr);
    if (config.paused) return;
    if (config.mint_enabled) {
        // do something with config.max_supply
    };
}
```

---

## Appendix C: Integration Examples

### Frontend Integration (TypeScript/SDK)

```typescript
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  FungibleAssetClient,
} from "@aptos-labs/ts-sdk";

class FungibleAssetManager {
  private client: FungibleAssetClient;
  private aptos: Aptos;

  constructor(network: Network = Network.TESTNET) {
    const config = new AptosConfig({ network });
    this.aptos = new Aptos(config);
    this.client = new FungibleAssetClient(this.aptos);
  }

  // Get FA balance for an account
  async getBalance(accountAddress: string, assetType: string): Promise<number> {
    try {
      const balance = await this.client.getCurrentFungibleAssetBalances({
        options: {
          where: {
            owner_address: { _eq: accountAddress },
            asset_type: { _eq: assetType },
          },
        },
      });

      return balance[0]?.amount || 0;
    } catch (error) {
      console.error("Error fetching balance:", error);
      throw error;
    }
  }

  // Transfer FA between accounts
  async transfer(
    sender: Account,
    recipient: string,
    amount: number,
    assetType: string
  ): Promise<string> {
    const transaction = await this.aptos.transaction.build.simple({
      sender: sender.accountAddress,
      data: {
        function: "0x1::primary_fungible_store::transfer",
        typeArguments: [assetType],
        functionArguments: [recipient, amount],
      },
    });

    const signedTxn = await this.aptos.signAndSubmitTransaction({
      signer: sender,
      transaction,
    });

    await this.aptos.waitForTransaction({
      transactionHash: signedTxn.hash,
    });

    return signedTxn.hash;
  }

  // Listen for FA events
  async listenToTransfers(
    assetType: string,
    callback: (event: any) => void
  ): Promise<void> {
    // Implementation would depend on your event listening setup
    // This is a conceptual example
    const eventFilter = {
      address: assetType,
      eventType: "0x1::fungible_asset::TransferEvent",
    };

    // Subscribe to events (pseudo-code)
    this.aptos.addEventListener(eventFilter, callback);
  }
}

// Usage example
async function example() {
  const manager = new FungibleAssetManager();
  const sender = Account.generate();
  const recipient = "0x1234...";
  const assetType = "0x1::aptos_coin::AptosCoin";

  try {
    // Check balance
    const balance = await manager.getBalance(
      sender.accountAddress.toString(),
      assetType
    );
    console.log(`Balance: ${balance}`);

    // Transfer tokens
    if (balance > 100) {
      const txHash = await manager.transfer(sender, recipient, 100, assetType);
      console.log(`Transfer completed: ${txHash}`);
    }

    // Listen for transfers
    await manager.listenToTransfers(assetType, (event) => {
      console.log("Transfer event:", event);
    });
  } catch (error) {
    console.error("Operation failed:", error);
  }
}
```

### Smart Contract Integration

```move
module integration::defi_pool {
    use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object};
    use std::signer;
    use std::vector;

    /// Liquidity pool supporting multiple FA types
    struct LiquidityPool has key {
        assets: vector<Object<Metadata>>,
        reserves: vector<u64>,
        total_shares: u64,
        fee_rate: u64, // Basis points
    }

    /// User's liquidity position
    struct LiquidityPosition has key {
        pool: Object<LiquidityPool>,
        shares: u64,
        rewards_debt: u64,
    }

    /// Add liquidity to a multi-asset pool
    public entry fun add_liquidity(
        user: &signer,
        pool_address: address,
        amounts: vector<u64>,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(pool_address);
        let user_addr = signer::address_of(user);

        assert!(vector::length(&amounts) == vector::length(&pool.assets), E_INVALID_ASSETS);

        // Calculate shares to mint based on current pool ratios
        let shares_to_mint = calculate_shares(&pool.reserves, &amounts);

        // Transfer assets from user to pool
        let i = 0;
        while (i < vector::length(&amounts)) {
            let asset = *vector::borrow(&pool.assets, i);
            let amount = *vector::borrow(&amounts, i);

            if (amount > 0) {
                primary_fungible_store::transfer(user, asset, pool_address, amount);
                let current_reserve = vector::borrow_mut(&mut pool.reserves, i);
                *current_reserve = *current_reserve + amount;
            };
            i = i + 1;
        };

        pool.total_shares = pool.total_shares + shares_to_mint;

        // Update user's position
        if (!exists<LiquidityPosition>(user_addr)) {
            move_to(user, LiquidityPosition {
                pool: object::address_to_object<LiquidityPool>(pool_address),
                shares: shares_to_mint,
                rewards_debt: 0,
            });
        } else {
            let position = borrow_global_mut<LiquidityPosition>(user_addr);
            position.shares = position.shares + shares_to_mint;
        };
    }

    /// Swap between two assets in the pool
    public entry fun swap(
        user: &signer,
        pool_address: address,
        input_asset_index: u64,
        output_asset_index: u64,
        input_amount: u64,
        min_output_amount: u64,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(pool_address);
        let user_addr = signer::address_of(user);

        // Validate indices
        assert!(input_asset_index < vector::length(&pool.assets), E_INVALID_INDEX);
        assert!(output_asset_index < vector::length(&pool.assets), E_INVALID_INDEX);
        assert!(input_asset_index != output_asset_index, E_SAME_ASSET);

        let input_asset = *vector::borrow(&pool.assets, input_asset_index);
        let output_asset = *vector::borrow(&pool.assets, output_asset_index);

        // Calculate output amount using constant product formula
        let input_reserve = *vector::borrow(&pool.reserves, input_asset_index);
        let output_reserve = *vector::borrow(&pool.reserves, output_asset_index);

        let output_amount = calculate_swap_output(
            input_amount,
            input_reserve,
            output_reserve,
            pool.fee_rate
        );

        assert!(output_amount >= min_output_amount, E_SLIPPAGE_TOO_HIGH);

        // Execute the swap
        primary_fungible_store::transfer(user, input_asset, pool_address, input_amount);
        primary_fungible_store::transfer(
            &get_pool_signer(pool_address),
            output_asset,
            user_addr,
            output_amount
        );

        // Update reserves
        let input_reserve_mut = vector::borrow_mut(&mut pool.reserves, input_asset_index);
        *input_reserve_mut = *input_reserve_mut + input_amount;

        let output_reserve_mut = vector::borrow_mut(&mut pool.reserves, output_asset_index);
        *output_reserve_mut = *output_reserve_mut - output_amount;
    }

    // Helper functions
    fun calculate_shares(reserves: &vector<u64>, amounts: &vector<u64>): u64 {
        // Implement proportional share calculation
        // This is simplified - production would use more sophisticated math
        let total_value = 0u64;
        let i = 0;
        while (i < vector::length(amounts)) {
            total_value = total_value + *vector::borrow(amounts, i);
            i = i + 1;
        };
        total_value // Simplified
    }

    fun calculate_swap_output(
        input_amount: u64,
        input_reserve: u64,
        output_reserve: u64,
        fee_rate: u64,
    ): u64 {
        // Constant product formula: x * y = k
        // With fees: output = (input * (10000 - fee) * output_reserve) /
        //                   ((input_reserve * 10000) + (input * (10000 - fee)))
        let input_with_fee = input_amount * (10000 - fee_rate);
        let numerator = input_with_fee * output_reserve;
        let denominator = (input_reserve * 10000) + input_with_fee;
        numerator / denominator
    }

    fun get_pool_signer(pool_address: address): signer {
        // In practice, you'd use an ExtendRef stored in the pool
        // This is conceptual
        account::create_signer_with_capability(&get_pool_signer_capability(pool_address))
    }
}
```
