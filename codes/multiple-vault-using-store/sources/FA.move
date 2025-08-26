module my_addrx::FA {
    use std::signer;
    use std::string;
    use aptos_framework::fungible_asset::{Self, Metadata, MintRef, BurnRef, TransferRef, FungibleStore};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object};
    use std::option;

    const ALREADY_INITIALIED: u64 = 0;

    const SEED: vector<u8> = b"THIS IS DUMMY TOKEN";

    struct System has key {
        metadata: Object<Metadata>,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef
    }

    public entry fun create(admin: &signer) {
        let admin_addr = signer::address_of(admin);

        assert!(!exists<System>(admin_addr), ALREADY_INITIALIED);

        let constructor_ref = object::create_named_object(admin, SEED);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(b"DUMMY"),
            string::utf8(b"DMY"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );

        let metadata = object::object_from_constructor_ref(&constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);

        move_to(
            admin,
            System { metadata, mint_ref, burn_ref, transfer_ref }
        );
    }

    public entry fun mint(admin: &signer, user: address, amount: u64) acquires System {
        let addrx = signer::address_of(admin);
        assert!(amount > 0);

        assert!(addrx == @my_addrx);

        let system = borrow_global<System>(@my_addrx);

        let user_primary_store_address =
            primary_fungible_store::primary_store_address(user, system.metadata);

        if (!fungible_asset::store_exists(user_primary_store_address)) {
            primary_fungible_store::create_primary_store(user, system.metadata);
        };

        let user_primary_store: Object<FungibleStore> = object::address_to_object(user_primary_store_address);

        let fa = fungible_asset::mint(&system.mint_ref, amount);
        fungible_asset::deposit(user_primary_store, fa);
    }

    #[view]
    public fun get_metadata(): Object<Metadata> acquires System {
        assert!(exists<System>(@my_addrx), ALREADY_INITIALIED);
        borrow_global<System>(@my_addrx).metadata
    }

    #[view]
    public fun get_primary_store_address(account: address): address acquires System {
        assert!(exists<System>(@my_addrx), ALREADY_INITIALIED);
        primary_fungible_store::primary_store_address(account, borrow_global<System>(@my_addrx).metadata)
    }
}

