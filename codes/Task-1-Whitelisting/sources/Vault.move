module my_addrx::Vault {
    use std::signer;
    use std::vector;
    use std::event;
    use std::simple_map::{Self, SimpleMap};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};

    // Error codes
    /// Signer is not the owner
    const ENOT_ADMIN: u64 = 0;
    /// Module already initialized
    const EALREADY_INITIALIZED: u64 = 1;
    /// Module not initialized
    const ENOT_INITIALIZED: u64 = 2;
    /// Address is not whitelisted
    const ENOT_WHITELISTED: u64 = 3;
    /// Address is already whitelisted
    const EALREADY_WHITELISTED: u64 = 4;
    /// Invalid deposit amount
    const EINVALID_DEPOSITAMOUNT: u64 = 5;
    /// Invalid withdrawal amount
    const EINVALID_WITHDRAWALAMOUNT: u64 = 6;
    /// Invalid Amount
    const EINVALID_AMOUNT: u64 = 7;

    // Seeds
    const TREASURY_SEED: vector<u8> = b"This TREASURY SEED!!!";

    /// System info store, contains signer cap for signing resource account withdrawal transactions, vault addr, FA metadata
    struct System has key {
        vault_addr: address,
        signer_capablity: SignerCapability,
        metadata: Object<Metadata>
    }

    /// Vault info, address deposited amount, address whitelisted
    struct VaultInfo has key, store {
        whitelisted: SimpleMap<address, bool>,
        whitelisted_amount: SimpleMap<address, u64>
    }

    #[event]
    struct Deposit has store, drop {
        by: address,
        amount: u64
    }

    #[event]
    struct Withdrawal has store, drop {
        by: address,
        amount: u64
    }

    #[event]
    struct Whitelisted has store, drop {
        user: address
    }

    #[event]
    struct Unwhitelisted has store, drop {
        user: address
    }

    /// Initialize the module
    /// It will create resource account for holding the module
    /// and create primary store for vault
    public entry fun create_vault_module(
        admin: &signer, m: Object<Metadata>
    ) {
        let addrx = signer::address_of(admin);
        assert!(!exists<System>(addrx), EALREADY_INITIALIZED);

        let (treasury_signer, treasury_cap) =
            account::create_resource_account(admin, TREASURY_SEED);

        let vault_addr = signer::address_of(&treasury_signer);

        let vault_primary_store_address =
            primary_fungible_store::primary_store_address(vault_addr, m);

        if (!fungible_asset::store_exists(vault_primary_store_address)) {
            primary_fungible_store::create_primary_store(vault_addr, m);
        };

        move_to<System>(
            admin,
            System { metadata: m, signer_capablity: treasury_cap, vault_addr }
        );

        move_to(
            &treasury_signer,
            VaultInfo {
                whitelisted: simple_map::create(),
                whitelisted_amount: simple_map::create()
            }
        );
    }

    /// Check if the signer is the owner
    fun assert_is_owner(admin: &address) {
        assert!(*admin == @my_addrx, ENOT_ADMIN);
    }

    fun assert_is_initialized() {
        assert!(exists<System>(@my_addrx), ENOT_INITIALIZED);
    }

    /// Check if the address is whitelisted
    fun assert_is_whitelisted(user: &address) acquires System, VaultInfo {
        let vault_addr = vault_address();
        let whitelisted = &borrow_global<VaultInfo>(vault_addr).whitelisted;
        assert!(*simple_map::borrow(whitelisted, user) == true, ENOT_WHITELISTED);
    }

    /// Check if the address is already whitelisted
    fun assert_is_already_whitelisted(user: &address) acquires System, VaultInfo {
        let vault_addr = vault_address();
        let whitelisted = &borrow_global<VaultInfo>(vault_addr).whitelisted;
        if (simple_map::contains_key(whitelisted, user)) {
            assert!(*simple_map::borrow(whitelisted, user) == false, EALREADY_WHITELISTED);
        };
    }

    /// Remove an address from the whitelist
    fun remove_whitelisted(user: &address) acquires System, VaultInfo {
        assert_is_whitelisted(user);
        let vault_addr = vault_address();
        let vault = borrow_global_mut<VaultInfo>(vault_addr);

        simple_map::upsert(&mut vault.whitelisted, *user, false);
        event::emit(Unwhitelisted { user: *user });
    }

    /// deposit amount from user to vault
    /// this will be transfer between user primary store and vault primary store
    fun deposit(user: &signer, amount: u64) acquires System, VaultInfo {
        let user_addrx = &signer::address_of(user);
        let vault_addr = vault_address();
        let vault = borrow_global_mut<VaultInfo>(vault_addr);
        assert!(amount > 0, EINVALID_DEPOSITAMOUNT);

        if (!simple_map::contains_key(&vault.whitelisted_amount, user_addrx)) {
            simple_map::add(&mut vault.whitelisted_amount, *user_addrx, 0);
        };

        let deposited_amount =
            simple_map::borrow_mut(&mut vault.whitelisted_amount, user_addrx);
        *deposited_amount += amount;

        let metadata = borrow_global<System>(@my_addrx).metadata;
        let user_primary_store_address =
            primary_fungible_store::primary_store_address(*user_addrx, metadata);

        let user_primary_store: Object<FungibleStore> =
            object::address_to_object(user_primary_store_address);

        let vault_primary_store_address =
            primary_fungible_store::primary_store_address(vault_addr, metadata);
        let vault_primary_store: Object<FungibleStore> =
            object::address_to_object(vault_primary_store_address);

        fungible_asset::transfer(
            user,
            user_primary_store,
            vault_primary_store,
            amount
        );
    }

    /// withdraw amount from vault to user
    /// this will be transfer between vault primary store and user primary store
    fun whithdraw(user: &signer, amount: u64) acquires System, VaultInfo {
        let user_addrx = &signer::address_of(user);
        let vault_addr = vault_address();
        let vault = borrow_global_mut<VaultInfo>(vault_addr);

        let deposited_amount =
            simple_map::borrow_mut(&mut vault.whitelisted_amount, user_addrx);

        assert!(*deposited_amount >= amount, EINVALID_WITHDRAWALAMOUNT);
        *deposited_amount -= amount;

        let sys = borrow_global<System>(@my_addrx);
        let user_primary_store_address =
            primary_fungible_store::primary_store_address(*user_addrx, sys.metadata);

        let user_primary_store: Object<FungibleStore> =
            object::address_to_object(user_primary_store_address);

        let vault_primary_store_address =
            primary_fungible_store::primary_store_address(vault_addr, sys.metadata);
        let vault_primary_store: Object<FungibleStore> =
            object::address_to_object(vault_primary_store_address);

        let vault_signer = account::create_signer_with_capability(&sys.signer_capablity);

        fungible_asset::transfer(
            &vault_signer,
            vault_primary_store,
            user_primary_store,
            amount
        );
    }

    /// Add an address to the whitelist
    public entry fun whitelist_address(admin: &signer, user: address) acquires System, VaultInfo {
        assert_is_initialized();
        let admin_addrx = &signer::address_of(admin);
        assert_is_owner(admin_addrx);

        assert_is_already_whitelisted(&user);

        let vault_addr = vault_address();
        let vault = borrow_global_mut<VaultInfo>(vault_addr);

        simple_map::add(&mut vault.whitelisted, user, true);

        event::emit(Whitelisted { user: user });
    }

    /// Add multiple addresses to the whitelist
    public entry fun whitelist_batch(
        admin: &signer, users: vector<address>
    ) acquires System, VaultInfo {
        assert_is_initialized();
        let admin_addrx = &signer::address_of(admin);
        assert_is_owner(admin_addrx);

        let vault_addr = vault_address();
        let vault = borrow_global_mut<VaultInfo>(vault_addr);

        let counter = 0;
        let len = users.length();
        let vec = vector::empty();

        while (counter < len) {
            event::emit(Whitelisted { user: *vector::borrow(&users, counter) });
            vector::push_back(&mut vec, true);

            counter += 1;
        };
        simple_map::add_all(&mut vault.whitelisted, users, vec);
    }

    /// Remove an address from the whitelist
    public entry fun remove_address_from_whitelist(
        admin: &signer, user: address
    ) acquires System, VaultInfo {
        assert_is_initialized();
        let admin_addrx = &signer::address_of(admin);
        assert_is_owner(admin_addrx);

        remove_whitelisted(&user);
    }

    /// Remove multiple addresses from the whitelist
    public entry fun remove_addresses_from_whitelist(
        admin: &signer, users: vector<address>
    ) acquires System, VaultInfo {
        assert_is_initialized();
        let admin_addrx = &signer::address_of(admin);
        assert_is_owner(admin_addrx);

        let counter = 0;
        let len = users.length();

        while (counter < len) {
            let user_addr = vector::borrow(&users, counter);

            remove_whitelisted(user_addr);

            counter += 1;
        };
    }

    /// Deposit funds but only from the whitelisted address
    public entry fun deposit_amount(user: &signer, amount: u64) acquires System, VaultInfo {
        assert_is_initialized();
        let account = &signer::address_of(user);
        assert_is_whitelisted(account);
        deposit(user, amount);

        event::emit(Deposit { by: *account, amount: amount });
    }

    /// Withdraw funds from contract
    public entry fun withdraw_amount(user: &signer, amount: u64) acquires System, VaultInfo {
        assert_is_initialized();
        let account = &signer::address_of(user);
        assert_is_whitelisted(account);
        whithdraw(user, amount);

        event::emit(Withdrawal { by: *account, amount: amount });
    }

    /// transfer funds from vault to provided address
    public entry fun move_fund(admin: &signer, user: address, amount: u64) acquires System {
        assert_is_initialized();
        let admin_addrx = &signer::address_of(admin);
        assert_is_owner(admin_addrx);

        let system = borrow_global<System>(@my_addrx);

        let vault_primary_store_address =
            primary_fungible_store::primary_store_address(
                system.vault_addr, system.metadata
            );

        let vault_primary_store: Object<FungibleStore> =
            object::address_to_object(vault_primary_store_address);

        assert!(fungible_asset::balance(vault_primary_store) >= amount, EINVALID_AMOUNT);

        let user_primary_store_address =
            primary_fungible_store::primary_store_address(user, system.metadata);

        if (!fungible_asset::store_exists(user_primary_store_address)) {
            primary_fungible_store::create_primary_store(user, system.metadata);
        };

        let user_primary_store: Object<FungibleStore> =
            object::address_to_object(user_primary_store_address);

        let vault_signer =
            account::create_signer_with_capability(&system.signer_capablity);

        fungible_asset::transfer(
            &vault_signer,
            vault_primary_store,
            user_primary_store,
            amount
        );
    }

    // Check if the address is whitelisted
    #[view]
    public fun is_whitelisted(user: address): bool acquires System, VaultInfo {
        assert_is_initialized();
        let vault_addr = vault_address();
        let whitelisted = &borrow_global<VaultInfo>(vault_addr).whitelisted;
        *simple_map::borrow(whitelisted, &user)
    }

    /// check user total deposited amount
    #[view]
    public fun total_deposited_amount(user: address): u64 acquires System, VaultInfo {
        assert_is_initialized();
        let vault_addr = vault_address();
        let vault = borrow_global<VaultInfo>(vault_addr);
        let deposited_amount = simple_map::borrow(&vault.whitelisted_amount, &user);
        *deposited_amount
    }

    /// Get the vault address
    #[view]
    public fun vault_address(): address acquires System {
        assert_is_initialized();
        borrow_global<System>(@my_addrx).vault_addr
    }

    #[test_only]
    use my_addrx::FA;
    #[test(admin = @my_addrx)]
    fun test_test_flow(admin: &signer) acquires System, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        whitelist_address(admin, alice_addrx);

        let total_amount = 100 * 100_000_000;
        let deposit_amount = total_amount / 10;
        FA::mint(admin, alice_addrx, total_amount);
        let alice_primary_store_address = FA::get_primary_store_address(alice_addrx);
        let p_store: Object<FungibleStore> =
            object::address_to_object(alice_primary_store_address);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            1
        );

        deposit_amount(alice, deposit_amount);
        assert!(total_deposited_amount(alice_addrx) == deposit_amount, 2);

        assert!(
            fungible_asset::balance(p_store) == 90 * 100_000_000,
            3
        );

        deposit_amount(alice, deposit_amount);
        assert!(
            total_deposited_amount(alice_addrx) == deposit_amount * 2,
            4
        );

        assert!(
            fungible_asset::balance(p_store) == 80 * 100_000_000,
            5
        );

        withdraw_amount(alice, deposit_amount);

        assert!(
            fungible_asset::balance(p_store) == 90 * 100_000_000,
            6
        );
    }

    #[test(admin = @my_addrx)]
    fun test_batch_add(admin: &signer) acquires System, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        let jack = &aptos_framework::account::create_account_for_test(@0x3);
        let jack_addrx = signer::address_of(jack);

        let ve = vector::empty();

        vector::push_back(&mut ve, alice_addrx);
        vector::push_back(&mut ve, jack_addrx);

        whitelist_batch(admin, ve);
        assert!(is_whitelisted(alice_addrx), 1);
        assert!(is_whitelisted(jack_addrx), 2);
    }

    #[test(admin = @my_addrx)]
    fun test_batch_remove(admin: &signer) acquires System, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        let jack = &aptos_framework::account::create_account_for_test(@0x3);
        let jack_addrx = signer::address_of(jack);

        let ve = vector::empty();

        vector::push_back(&mut ve, alice_addrx);
        vector::push_back(&mut ve, jack_addrx);

        whitelist_batch(admin, ve);
        assert!(is_whitelisted(alice_addrx), 1);
        assert!(is_whitelisted(jack_addrx), 2);

        remove_addresses_from_whitelist(admin, ve);
        assert!(!is_whitelisted(alice_addrx), 3);
        assert!(!is_whitelisted(jack_addrx), 4);

    }

    #[test(admin = @my_addrx)]
    fun test_move_fund(admin: &signer) acquires System, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        whitelist_address(admin, alice_addrx);

        let total_amount = 100 * 100_000_000;
        let deposit_amount = total_amount / 10;
        FA::mint(admin, alice_addrx, total_amount);
        let alice_primary_store_address = FA::get_primary_store_address(alice_addrx);
        let p_store: Object<FungibleStore> =
            object::address_to_object(alice_primary_store_address);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            1
        );

        deposit_amount(alice, deposit_amount);
        assert!(total_deposited_amount(alice_addrx) == deposit_amount, 2);

        let jack = &aptos_framework::account::create_account_for_test(@0x3);
        let jack_addrx = signer::address_of(jack);

        let jack_primary_store_address = FA::get_primary_store_address(jack_addrx);

        move_fund(admin, jack_addrx, deposit_amount);

        let j_store: Object<FungibleStore> =
            object::address_to_object(jack_primary_store_address);
        assert!(fungible_asset::balance(j_store) == deposit_amount, 3);
    }
}

