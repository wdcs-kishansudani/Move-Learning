module my_addrx::Vault {
    use std::signer;
    use std::vector;
    use std::simple_map::{Self, SimpleMap};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};
    use aptos_framework::primary_fungible_store;

    const EMODULE_ALREADY_INITIALIED: u64 = 0;
    const EVAULT_DOENT_EXIST: u64 = 1;
    const EINSUFFICIENT_VAULT_BALANCE: u64 = 2;
    const EINVALID_AMOUNT: u64 = 3;
    const EPRIMARY_STORE_DOESNT_EXIST: u64 = 4;
    const EINVAILD_INDEX: u64 = 5;

    struct VaultInfo has key {
        metadata: Object<Metadata>,
        vaults: SimpleMap<address, u64>
    }

    struct SecondaryVaults has key {
        stores: vector<Object<FungibleStore>>,
        store_count: u64,
        amount: u64
    }

    public entry fun create_vault_module(
        admin: &signer, m: Object<Metadata>
    ) {
        let addrx = signer::address_of(admin);
        assert!(!exists<VaultInfo>(addrx), EMODULE_ALREADY_INITIALIED);

        move_to<VaultInfo>(
            admin,
            VaultInfo { metadata: m, vaults: simple_map::create() }
        );
    }

    fun create_secondary_store(user: &signer): u64 acquires VaultInfo, SecondaryVaults {
        let addrx = signer::address_of(user);
        let system = borrow_global_mut<VaultInfo>(@my_addrx);

        let secondary_store = borrow_global_mut<SecondaryVaults>(addrx);
        secondary_store.store_count += 1;

        let object_constructor_ref = object::create_object(addrx);
        let object_store =
            fungible_asset::create_store(&object_constructor_ref, system.metadata);

        secondary_store.stores.push_back(object_store);

        secondary_store.stores.length() - 1
    }

    public entry fun deposit(user: &signer, amount: u64) acquires VaultInfo, SecondaryVaults {
        assert!(amount > 0, EINVALID_AMOUNT);
        let addrx = signer::address_of(user);
        let metadata = borrow_global<VaultInfo>(@my_addrx).metadata;
        let user_primary_store_address =
            primary_fungible_store::primary_store_address(addrx, metadata);
        assert!(
            fungible_asset::store_exists(user_primary_store_address),
            EPRIMARY_STORE_DOESNT_EXIST
        );

        if (!exists<SecondaryVaults>(addrx)) {
            move_to(
                user,
                SecondaryVaults { stores: vector::empty(), store_count: 0, amount: 0 }
            );
        };

        let latest_store_count = create_secondary_store(user);

        let stores = borrow_global_mut<SecondaryVaults>(addrx);
        let store = stores.stores.borrow(latest_store_count);

        stores.amount += amount;

        let user_primary_store = object::address_to_object(user_primary_store_address);
        fungible_asset::transfer(user, user_primary_store, *store, amount);
    }

    public entry fun withdraw(user: &signer, amount: u64) acquires VaultInfo, SecondaryVaults {
        let addrx = signer::address_of(user);

        assert!(amount > 0, EINVALID_AMOUNT);
        assert!(exists<SecondaryVaults>(addrx), EVAULT_DOENT_EXIST);
        let stores = borrow_global_mut<SecondaryVaults>(addrx);
        assert!(stores.amount >= amount, EINSUFFICIENT_VAULT_BALANCE);
        let metadata = borrow_global<VaultInfo>(@my_addrx).metadata;

        let vault_len = stores.store_count;
        let required_amount = amount;
        let counter = 0;

        let user_primary_store_address =
            primary_fungible_store::primary_store_address(addrx, metadata);

        if (!fungible_asset::store_exists(user_primary_store_address)) {
            primary_fungible_store::create_primary_store(addrx, metadata);
        };

        let user_primary_store = object::address_to_object(user_primary_store_address);

        while (counter < vault_len && required_amount > 0) {
            let store = stores.stores.borrow(counter);
            let store_balance = fungible_asset::balance(*store);
            let w_amount;
            if (store_balance > required_amount) {
                w_amount = required_amount;
                required_amount = 0;
            } else {
                w_amount = store_balance;
                required_amount -= store_balance;
            };
            stores.amount -= w_amount;

            fungible_asset::transfer(user, *store, user_primary_store, w_amount);
            counter += 1;
        };
    }

    #[view]
    public fun vault_total_balance(account: address): u64 acquires SecondaryVaults {
        assert!(exists<SecondaryVaults>(account), EVAULT_DOENT_EXIST);
        borrow_global<SecondaryVaults>(account).amount
    }

    #[view]
    public fun get_total_vault_count(account: address): u64 acquires SecondaryVaults {
        assert!(exists<SecondaryVaults>(account), EVAULT_DOENT_EXIST);
        borrow_global<SecondaryVaults>(account).store_count
    }

    public fun get_vault_index_balance(account: address, index: u64): u64 acquires SecondaryVaults {
        assert!(exists<SecondaryVaults>(account), EVAULT_DOENT_EXIST);
        let stores = borrow_global<SecondaryVaults>(account);
        assert!(stores.store_count > index, EINVAILD_INDEX);

        let store = stores.stores.borrow(index);
        fungible_asset::balance(*store)
    }

    #[test_only]
    use my_addrx::FA;
    #[test(admin = @my_addrx)]
    fun test_flow(admin: &signer) acquires SecondaryVaults, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        FA::mint(admin, alice_addrx, 100 * 100_000_000);
        let alice_primary_store_address = FA::get_primary_store_address(alice_addrx);
        let p_store: Object<FungibleStore> =
            object::address_to_object(alice_primary_store_address);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            2
        );

        let deposit_amount = 10 * 100_000_000;
        deposit(alice, deposit_amount);

        assert!(vault_total_balance(alice_addrx) == deposit_amount, 3);
        assert!(get_total_vault_count(alice_addrx) == 1, 4);
        assert!(get_vault_index_balance(alice_addrx, 0) == deposit_amount, 5);
        assert!(
            fungible_asset::balance(p_store) == 90 * 100_000_000,
            6
        );

        deposit(alice, deposit_amount);

        assert!(
            vault_total_balance(alice_addrx) == deposit_amount * 2,
            7
        );
        assert!(get_total_vault_count(alice_addrx) == 2, 8);
        assert!(get_vault_index_balance(alice_addrx, 1) == deposit_amount, 9);
        assert!(
            fungible_asset::balance(p_store) == 80 * 100_000_000,
            10
        );

        withdraw(alice, deposit_amount * 2);

        assert!(vault_total_balance(alice_addrx) == 0, 11);
        assert!(get_total_vault_count(alice_addrx) == 2, 12);
        assert!(get_vault_index_balance(alice_addrx, 0) == 0, 13);
        assert!(get_vault_index_balance(alice_addrx, 1) == 0, 14);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            15
        );
    }

    #[test(admin = @my_addrx)]
    #[expected_failure(abort_code = EVAULT_DOENT_EXIST)]
    fun test_withdraw_without_deposit_amount(admin: &signer) acquires SecondaryVaults, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        FA::mint(admin, alice_addrx, 100 * 100_000_000);
        let alice_primary_store_address = FA::get_primary_store_address(alice_addrx);
        let p_store: Object<FungibleStore> =
            object::address_to_object(alice_primary_store_address);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            2
        );

        let deposit_amount = 10 * 100_000_000;

        withdraw(alice, deposit_amount * 2);
    }

    #[test(admin = @my_addrx)]
    #[expected_failure(abort_code = EINSUFFICIENT_VAULT_BALANCE)]
    fun test_withdraw_insufficent_amount(admin: &signer) acquires SecondaryVaults, VaultInfo {
        FA::create(admin);

        let metadata = FA::get_metadata();
        create_vault_module(admin, metadata);

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        FA::mint(admin, alice_addrx, 100 * 100_000_000);
        let alice_primary_store_address = FA::get_primary_store_address(alice_addrx);
        let p_store: Object<FungibleStore> =
            object::address_to_object(alice_primary_store_address);
        assert!(
            fungible_asset::balance(p_store) == 100 * 100_000_000,
            2
        );

        let deposit_amount = 10 * 100_000_000;

        deposit(alice, deposit_amount);

        assert!(vault_total_balance(alice_addrx) == deposit_amount, 3);
        assert!(get_total_vault_count(alice_addrx) == 1, 4);
        assert!(get_vault_index_balance(alice_addrx, 0) == deposit_amount, 5);
        assert!(
            fungible_asset::balance(p_store) == 90 * 100_000_000,
            6
        );

        withdraw(alice, deposit_amount * 2);
    }
}

