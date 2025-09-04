module my_addrx::FA {
    use std::signer;
    use std::string;
    use std::option;
    use std::object::{Self, Object};
    use aptos_framework::fungible_asset::{
        Self,
        Metadata,
        BurnRef,
        MintRef,
        TransferRef,
        FungibleStore
    };
    use aptos_framework::primary_fungible_store;

    friend my_addrx::Escrow;

    const ENOT_ADMIN: u64 = 1;
    const EINVALID_AMOUNT: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const EPRIMARY_STORE_NOT_EXIST: u64 = 4;
    const EINSUFFICIENT_AMOUNT: u64 = 5;
    const EPRIMARY_STORE_ALREADY_EXIST: u64 = 6;

    const SEED: vector<u8> = b"THIS IS AWESOME TOKEN SEED!!!!";

    struct System has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>
    }

    fun init_module(admin: &signer) {
        let admin_addrx = signer::address_of(admin);
        assert!(!exists<System>(admin_addrx), EALREADY_INITIALIZED);

        let constructor_ref = &object::create_named_object(admin, SEED);
        let max_supply = option::none();
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            max_supply,
            string::utf8(b"AWESOME TOKEN"),
            string::utf8(b"AWT"),
            6,
            string::utf8(b""),
            string::utf8(b"")
        );

        move_to(
            admin,
            System {
                mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
                metadata: object::object_from_constructor_ref(constructor_ref)
            }
        );
    }

    fun assert_is_owner(user: &address) {
        assert!(*user == @my_addrx, ENOT_ADMIN);
    }

    public entry fun register(account: &signer) acquires System {
        let addrx = &signer::address_of(account);
        assert!(exists<System>(@my_addrx));

        let metadata = borrow_global<System>(@my_addrx).metadata;

        assert!(
            !primary_fungible_store::primary_store_exists(*addrx, metadata),
            EPRIMARY_STORE_ALREADY_EXIST
        );

        primary_fungible_store::create_primary_store(*addrx, metadata);
    }

    public entry fun mint(admin: &signer, user: address, amount: u64) acquires System {
        let admin_addrx = signer::address_of(admin);
        assert!(amount > 0, EINVALID_AMOUNT);
        assert_is_owner(&admin_addrx);
        let system = borrow_global<System>(@my_addrx);

        assert!(
            primary_fungible_store::primary_store_exists(user, system.metadata),
            EPRIMARY_STORE_NOT_EXIST
        );

        primary_fungible_store::mint(&system.mint_ref, user, amount);
    }

    public entry fun burn(admin: &signer, user: address, amount: u64) acquires System {
        let admin_addrx = signer::address_of(admin);
        assert!(amount > 0, EINVALID_AMOUNT);
        assert_is_owner(&admin_addrx);
        let system = borrow_global<System>(@my_addrx);

        assert!(
            primary_fungible_store::primary_store_exists(user, system.metadata),
            EPRIMARY_STORE_NOT_EXIST
        );

        assert!(
            primary_fungible_store::balance(user, system.metadata) >= amount,
            EINSUFFICIENT_AMOUNT
        );

        primary_fungible_store::burn(&system.burn_ref, user, amount);
    }

    public(friend) entry fun transfer(
        from: Object<FungibleStore>, to: Object<FungibleStore>, amount: u64
    ) acquires System {
        assert!(amount > 0, EINVALID_AMOUNT);
        let system = borrow_global<System>(@my_addrx);

        fungible_asset::transfer_with_ref(&system.transfer_ref, from, to, amount);
    }

    #[view]
    public fun check_balance(addr: address): u64 acquires System {
        let system = borrow_global<System>(@my_addrx);
        assert!(
            primary_fungible_store::primary_store_exists(addr, system.metadata),
            EPRIMARY_STORE_NOT_EXIST
        );
        primary_fungible_store::balance(addr, system.metadata)
    }

    #[view]
    public fun get_metadata(): Object<Metadata> acquires System {
        borrow_global<System>(@my_addrx).metadata
    }

    #[view]
    public fun get_primary_store_address(addr: address): address acquires System {
        let system = borrow_global<System>(@my_addrx);
        assert!(
            primary_fungible_store::primary_store_exists(addr, system.metadata),
            EPRIMARY_STORE_NOT_EXIST
        );

        primary_fungible_store::primary_store_address(addr, system.metadata)
    }

    #[test_only]
    public fun test_init(account: &signer) {
        init_module(account);
    }
}

