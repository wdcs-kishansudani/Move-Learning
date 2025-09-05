module my_addrx::Bank {
    use std::signer;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, BurnRef, MintRef, TransferRef};
    use aptos_framework::primary_fungible_store;
    use std::option;
    use std::string;
    use std::table::{Self, Table};

    const EALREADY_INITIALIZED: u64 = 1;
    const ENO_MINT_CAP: u64 = 2;
    const ENO_BURN_CAP: u64 = 3;
    const ENO_TRANSFER_CAP: u64 = 4;
    const ENOT_ADMIN: u64 = 5;
    const EALREADY_MINT_CAP: u64 = 6;
    const EALREADY_BURN_CAP: u64 = 7;
    const EALREADY_TRANSFER_CAP: u64 = 8;
    const ENOT_DELEGATE: u64 = 9;

    struct Currency<phantom CurrencyType> has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>
    }

    struct MintCap<phantom CurrencyType> has key {}

    struct BurnCap<phantom CurrencyType> has key {}

    struct TransferCap<phantom CurrencyType> has key {}

    struct Delegates<phantom CurrencyType> has key {
        table: Table<address, bool>
    }

    public fun deploy<T>(admin: &signer, seed: vector<u8>) {
        let admin_addr = signer::address_of(admin);
        assert!(
            !exists<Currency<T>>(admin_addr),
            EALREADY_INITIALIZED
        );

        // create underlying object and primary store
        let constructor_ref = &object::create_named_object(admin, seed);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"T"),
            string::utf8(b"T"),
            8u8,
            string::utf8(b""),
            string::utf8(b"")
        );

        move_to(
            admin,
            Currency<T> {
                mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
                metadata: object::object_from_constructor_ref(constructor_ref)
            }
        );

        move_to(admin, MintCap<T> {});
        move_to(admin, BurnCap<T> {});
        move_to(admin, TransferCap<T> {});

        let t = table::new<address, bool>();
        move_to(admin, Delegates<T> { table: t });
    }

    public fun mint<T>(issuer: &signer, to: address, amount: u64) acquires Currency {
        let issuer_addr = signer::address_of(issuer);
        assert!(mint_cap_exist<T>(issuer_addr), ENO_MINT_CAP);

        let currency = borrow_global_mut<Currency<T>>(get_deployer_address());
        primary_fungible_store::mint(&currency.mint_ref, to, amount);

    }

    public fun burn<T>(issuer: &signer, from: address, amount: u64) acquires Currency {
        let issuer_addr = signer::address_of(issuer);
        assert!(burn_cap_exist<T>(issuer_addr), ENO_BURN_CAP);

        let currency = borrow_global_mut<Currency<T>>(get_deployer_address());
        primary_fungible_store::burn(&currency.burn_ref, from, amount);
    }

    public fun transfer<T>(
        issuer: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires Currency {
        let issuer_addr = signer::address_of(issuer);
        assert!(transfer_cap_exist<T>(issuer_addr), ENO_TRANSFER_CAP);

        let currency = borrow_global_mut<Currency<T>>(get_deployer_address());
        primary_fungible_store::transfer_with_ref(
            &currency.transfer_ref, from, to, amount
        );
    }

    public fun assign_mint_cap<T>(admin: &signer, to: &signer) acquires Delegates {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);
        let to_addr = signer::address_of(to);
        assert!(!mint_cap_exist<T>(to_addr), EALREADY_MINT_CAP);
        move_to(to, MintCap<T> {});

        let d = borrow_global_mut<Delegates<T>>(@my_addrx);
        table::add(&mut d.table, to_addr, true);
    }

    public fun revoke_mint_cap<T>(admin: &signer, from: address) acquires MintCap, Delegates {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);
        assert!(mint_cap_exist<T>(from), ENO_MINT_CAP);

        let MintCap<T> {} = move_from<MintCap<T>>(from);
        let d = borrow_global_mut<Delegates<T>>(@my_addrx);
        table::remove(&mut d.table, from);
    }

    // views
    #[view]
    public fun mint_cap_exist<T>(addr: address): bool {
        exists<MintCap<T>>(addr)
    }

    #[view]
    public fun burn_cap_exist<T>(addr: address): bool {
        exists<BurnCap<T>>(addr)
    }

    #[view]
    public fun transfer_cap_exist<T>(addr: address): bool {
        exists<TransferCap<T>>(addr)
    }

    fun get_deployer_address(): address {
        @my_addrx
    }

    #[view]
    public fun balance<T>(addr: address): u64 acquires Currency {
        let currency = borrow_global<Currency<T>>(get_deployer_address());
        primary_fungible_store::balance(addr, currency.metadata)
    }

    #[view]
    public fun total_supply<T>(): option::Option<u128> acquires Currency {
        let currency = borrow_global<Currency<T>>(get_deployer_address());
        fungible_asset::supply(currency.metadata)
    }

    #[test_only]
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct USD has key {}

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct EUR has key {}

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct INR has key {}

    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test_flow(admin: &signer, alice: &signer, bob: &signer) acquires Currency, MintCap, Delegates {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        deploy<USD>(admin, b"USD");

        mint<USD>(admin, alice_addrx, 1000);

        assert!(balance<USD>(alice_addrx) == 1000, 1);

        transfer<USD>(admin, alice_addrx, bob_addrx, 100);

        assert!(balance<USD>(bob_addrx) == 100, 4);

        assert!(balance<USD>(alice_addrx) == 900, 7);

        burn<USD>(admin, alice_addrx, 500);

        assert!(balance<USD>(alice_addrx) == 400, 10);

        assert!(total_supply<USD>() == option::some(500), 13);

        assign_mint_cap<USD>(admin, alice);
        mint<USD>(alice, alice_addrx, 1000);
        assert!(balance<USD>(alice_addrx) == 1400, 16);
        assert!(total_supply<USD>() == option::some(1500), 17);

        revoke_mint_cap<USD>(admin, alice_addrx);
        assert!(!mint_cap_exist<USD>(alice_addrx), 22);

    }
}

