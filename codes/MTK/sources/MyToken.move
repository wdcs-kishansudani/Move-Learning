module my_addrx::Bank {
    use std::signer;
    use std::option;
    use std::object::{Self, Object};
    use std::string;
    use aptos_framework::fungible_asset::{Self, Metadata, BurnRef, MintRef, TransferRef};
    use aptos_framework::primary_fungible_store;

    const EALREADY_INITIALIZED: u64 = 1;
    const ENO_MINT_CAP: u64 = 2;
    const ENO_BURN_CAP: u64 = 3;
    const ENO_TRANSFER_CAP: u64 = 4;
    const ENOT_ADMIN: u64 = 5;
    const EALREADY_MINT_CAP: u64 = 6;
    const EALREADY_BURN_CAP: u64 = 7;
    const EALREADY_TRANSFER_CAP: u64 = 8;

    struct Currency<phantom CurrencyType> has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>
    }

    struct MintCap<phantom CurrencyType> has key {}

    struct BurnCap<phantom CurrencyType> has key {}

    struct TransferCap<phantom CurrencyType> has key {}

    fun deploy<T>(admin: &signer, seed: vector<u8>) {
        assert!(
            !exists<Currency<T>>(signer::address_of(admin)),
            EALREADY_INITIALIZED
        );

        let constructor_ref = &object::create_named_object(admin, seed);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"T"),
            string::utf8(b"T"),
            8,
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
    }

    fun mint<T>(admin: &signer, to: address, amount: u64) acquires Currency {

        let admin_addrx = signer::address_of(admin);
        assert!(mint_cap_exist<T>(admin_addrx), ENO_MINT_CAP);

        let currency = borrow_global_mut<Currency<T>>(@my_addrx);
        primary_fungible_store::mint(&currency.mint_ref, to, amount);
    }

    fun burn<T>(admin: &signer, from: address, amount: u64) acquires Currency {
        let admin_addrx = signer::address_of(admin);

        assert!(burn_cap_exist<T>(admin_addrx), ENO_BURN_CAP);

        let currency = borrow_global_mut<Currency<T>>(@my_addrx);
        primary_fungible_store::burn(&currency.burn_ref, from, amount);
    }

    fun transfer<T>(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires Currency {
        let admin_addrx = signer::address_of(admin);
        assert!(
            transfer_cap_exist<T>(admin_addrx),
            ENO_TRANSFER_CAP
        );
        let currency = borrow_global_mut<Currency<T>>(@my_addrx);
        primary_fungible_store::transfer_with_ref(
            &currency.transfer_ref, from, to, amount
        );
    }

    fun assign_mint_cap<T>(admin: &signer, to: &signer) {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(
            !mint_cap_exist<T>(signer::address_of(to)),
            EALREADY_MINT_CAP
        );
        move_to(to, MintCap<T> {});
    }

    fun assign_burn_cap<T>(admin: &signer, to: &signer) {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(
            !burn_cap_exist<T>(signer::address_of(to)),
            EALREADY_BURN_CAP
        );
        move_to(to, BurnCap<T> {});
    }

    fun assign_transfer_cap<T>(admin: &signer, to: &signer) {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(
            !transfer_cap_exist<T>(signer::address_of(to)),
            EALREADY_TRANSFER_CAP
        );
        move_to(to, TransferCap<T> {});
    }

    fun invoke_mint_cap<T>(admin: &signer, from: address) acquires MintCap {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(mint_cap_exist<T>(from), ENO_MINT_CAP);

        let MintCap<T> {} = move_from<MintCap<T>>(from);
    }

    fun invoke_burn_cap<T>(admin: &signer, from: address) acquires BurnCap {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(burn_cap_exist<T>(from), ENO_BURN_CAP);

        let BurnCap<T> {} = move_from<BurnCap<T>>(from);
    }

    fun invoke_transfer_cap<T>(admin: &signer, from: address) acquires TransferCap {
        assert!(signer::address_of(admin) == @my_addrx, ENOT_ADMIN);

        assert!(
            transfer_cap_exist<T>(from),
            ENO_TRANSFER_CAP
        );

        let TransferCap<T> {} = move_from<TransferCap<T>>(from);
    }

    #[view]
    fun mint_cap_exist<T>(addr: address): bool {
        exists<MintCap<T>>(addr)
    }

    #[view]
    fun burn_cap_exist<T>(addr: address): bool {
        exists<BurnCap<T>>(addr)
    }

    #[view]
    fun transfer_cap_exist<T>(addr: address): bool {
        exists<TransferCap<T>>(addr)
    }

    #[view]
    fun balance<T>(addr: address): u64 acquires Currency {
        let currency = borrow_global<Currency<T>>(@my_addrx);
        primary_fungible_store::balance(addr, currency.metadata)
    }

    #[view]
    fun total_supply<T>(): option::Option<u128> acquires Currency {
        let currency = borrow_global<Currency<T>>(@my_addrx);
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
    fun test_flow(
        admin: &signer, alice: &signer, bob: &signer
    ) acquires Currency, MintCap, BurnCap, TransferCap {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        deploy<USD>(admin, b"USD");
        deploy<EUR>(admin, b"EUR");
        deploy<INR>(admin, b"INR");

        mint<USD>(admin, alice_addrx, 1000);
        mint<EUR>(admin, alice_addrx, 1000);
        mint<INR>(admin, alice_addrx, 1000);

        assert!(balance<USD>(alice_addrx) == 1000, 1);
        assert!(balance<EUR>(alice_addrx) == 1000, 2);
        assert!(balance<INR>(alice_addrx) == 1000, 3);

        transfer<USD>(admin, alice_addrx, bob_addrx, 100);
        transfer<EUR>(admin, alice_addrx, bob_addrx, 100);
        transfer<INR>(admin, alice_addrx, bob_addrx, 100);

        assert!(balance<USD>(bob_addrx) == 100, 4);
        assert!(balance<EUR>(bob_addrx) == 100, 5);
        assert!(balance<INR>(bob_addrx) == 100, 6);

        assert!(balance<USD>(alice_addrx) == 900, 7);
        assert!(balance<EUR>(alice_addrx) == 900, 8);
        assert!(balance<INR>(alice_addrx) == 900, 9);

        burn<USD>(admin, alice_addrx, 500);
        burn<EUR>(admin, alice_addrx, 500);
        burn<INR>(admin, alice_addrx, 500);

        assert!(balance<USD>(alice_addrx) == 400, 10);
        assert!(balance<EUR>(alice_addrx) == 400, 11);
        assert!(balance<INR>(alice_addrx) == 400, 12);

        assert!(total_supply<USD>() == option::some(500), 13);
        assert!(total_supply<EUR>() == option::some(500), 14);
        assert!(total_supply<INR>() == option::some(500), 15);

        assign_mint_cap<USD>(admin, alice);
        mint<USD>(alice, alice_addrx, 1000);
        assert!(balance<USD>(alice_addrx) == 1400, 16);
        assert!(total_supply<USD>() == option::some(1500), 17);

        assign_burn_cap<USD>(admin, alice);
        burn<USD>(alice, alice_addrx, 500);
        assert!(balance<USD>(alice_addrx) == 900, 18);
        assert!(total_supply<USD>() == option::some(1000), 19);

        assign_transfer_cap<USD>(admin, alice);
        transfer<USD>(alice, alice_addrx, bob_addrx, 100);
        assert!(balance<USD>(bob_addrx) == 200, 20);
        assert!(balance<USD>(alice_addrx) == 800, 21);

        invoke_mint_cap<USD>(admin, alice_addrx);
        assert!(!mint_cap_exist<USD>(alice_addrx), 22);

        invoke_burn_cap<USD>(admin, alice_addrx);
        assert!(!burn_cap_exist<USD>(alice_addrx), 23);

        invoke_transfer_cap<USD>(admin, alice_addrx);
        assert!(!transfer_cap_exist<USD>(alice_addrx), 24);

    }
}

