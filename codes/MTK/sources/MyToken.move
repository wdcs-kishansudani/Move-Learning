module my_addrx::Bank {
    use std::signer;
    use std::option;
    use std::object::{Self, Object};
    use std::string;
    use aptos_framework::fungible_asset::{Self, Metadata, BurnRef, MintRef, TransferRef};
    use aptos_framework::primary_fungible_store;

    struct USD {}

    struct EUR {}

    struct INR {}

    struct Currency<phantom CurrencyType> has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>
    }

    fun init_module(admin: &signer) {

        let constructor_ref = &object::create_named_object(admin, b"USD");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"USD"),
            string::utf8(b"USD"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );

        let usd = Currency<USD> {
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
            metadata: object::object_from_constructor_ref(constructor_ref)
        };

        let constructor_ref = &object::create_named_object(admin, b"EUR");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"EUR"),
            string::utf8(b"EUR"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );

        let eur = Currency<EUR> {
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
            metadata: object::object_from_constructor_ref(constructor_ref)
        };

        let constructor_ref = &object::create_named_object(admin, b"INR");
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"INR"),
            string::utf8(b"INR"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );

        let inr = Currency<INR> {
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
            metadata: object::object_from_constructor_ref(constructor_ref)
        };

        move_to(admin, usd);
        move_to(admin, eur);
        move_to(admin, inr);
    }

    fun mint<T>(admin: &signer, to: address, amount: u64) acquires Currency {
        let admin_addrx = signer::address_of(admin);

        let currency = borrow_global_mut<Currency<T>>(admin_addrx);
        primary_fungible_store::mint(&currency.mint_ref, to, amount);
    }

    fun burn<T>(admin: &signer, from: address, amount: u64) acquires Currency {
        let admin_addrx = signer::address_of(admin);

        let currency = borrow_global_mut<Currency<T>>(admin_addrx);
        primary_fungible_store::burn(&currency.burn_ref, from, amount);
    }

    fun transfer<T>(
        admin: &signer,
        from: address,
        to: address,
        amount: u64
    ) acquires Currency {
        let admin_addrx = signer::address_of(admin);

        let currency = borrow_global_mut<Currency<T>>(admin_addrx);
        primary_fungible_store::transfer_with_ref(
            &currency.transfer_ref, from, to, amount
        );
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

    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test_flow(admin: &signer, alice: &signer, bob: &signer) acquires Currency {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        init_module(admin);

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

    }
}

