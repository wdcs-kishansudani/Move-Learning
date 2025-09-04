module my_addrx::Escrow {
    use std::signer;
    use std::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::smart_table::{Self, SmartTable};
    use my_addrx::FA;

    const EID_NOT_FOUND: u64 = 2;
    const EINVALID_AMOUNT: u64 = 3;
    const EONLY_BUYER: u64 = 4;
    const EINVALID_ADDRESS: u64 = 5;
    const EINSUFFICIENT_AMOUNT: u64 = 6;
    const EALREADY_RELEASED: u64 = 7;
    const EPRIMARY_STORE_NOT_EXIST: u64 = 8;

    struct Escrow has key {
        buyer: address,
        seller: address,
        token: Object<FungibleStore>,
        amount: u64,
        released: bool
    }

    struct Vault has key {
        vault: SmartTable<u64, address>,
        vault_owner: SmartTable<u64, address>,
        next_escrow_id: u64
    }

    fun init_module(admin: &signer) {
        let admin_addrx = signer::address_of(admin);
        assert!(!exists<Vault>(admin_addrx));

        move_to(
            admin,
            Vault {
                vault: smart_table::new(),
                vault_owner: smart_table::new(),
                next_escrow_id: 0
            }
        );
    }

    fun create(
        buyer: address,
        seller: address,
        amount: u64,
        metadata: Object<Metadata>
    ) acquires Vault, Escrow {
        assert!(
            primary_fungible_store::primary_store_exists(buyer, metadata),
            EPRIMARY_STORE_NOT_EXIST
        );

        let buyer_store_address =
            primary_fungible_store::primary_store_address(buyer, metadata);
        let buyer_store = object::address_to_object<FungibleStore>(buyer_store_address);

        let constructor_ref = &object::create_object(buyer);
        let fs = fungible_asset::create_store(constructor_ref, metadata);

        let escrow = Escrow { buyer, seller, token: fs, amount, released: false };

        let vault = borrow_global_mut<Vault>(@my_addrx);

        let object_signer = &object::generate_signer(constructor_ref);
        move_to(object_signer, escrow);

        let next_escrow_id = vault.next_escrow_id;
        vault.vault.add(next_escrow_id, signer::address_of(object_signer));
        vault.vault_owner.add(next_escrow_id, buyer);

        vault.next_escrow_id += 1;

        let es = borrow_global<Escrow>(signer::address_of(object_signer));

        FA::transfer(buyer_store, es.token, es.amount);
    }

    fun release(escrow_id: u64) acquires Vault, Escrow {
        let vault = borrow_global_mut<Vault>(@my_addrx);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);

        let escrow = borrow_global_mut<Escrow>(buyer_signer_address);

        assert!(!escrow.released, EALREADY_RELEASED);

        let metadata = FA::get_metadata();

        if (!primary_fungible_store::primary_store_exists(escrow.seller, metadata)) {
            primary_fungible_store::create_primary_store(escrow.seller, metadata);
        };

        let seller_store_address =
            primary_fungible_store::primary_store_address(escrow.seller, metadata);
        let seller_store = object::address_to_object<FungibleStore>(seller_store_address);

        escrow.released = true;

        FA::transfer(escrow.token, seller_store, escrow.amount);
    }

    fun cancel(escrow_id: u64) acquires Vault, Escrow {
        let vault = borrow_global_mut<Vault>(@my_addrx);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);

        let escrow = borrow_global_mut<Escrow>(buyer_signer_address);

        assert!(!escrow.released, EALREADY_RELEASED);

        let metadata = FA::get_metadata();

        let buyer_primary_store_address =
            primary_fungible_store::primary_store_address(escrow.buyer, metadata);
        let buyer_store =
            object::address_to_object<FungibleStore>(buyer_primary_store_address);

        escrow.released = true;

        FA::transfer(escrow.token, buyer_store, escrow.amount);
    }

    entry fun create_escrow(buyer: &signer, seller: address, amount: u64) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        assert!(buyer_addr != seller, EINVALID_ADDRESS);
        assert!(amount > 0, EINVALID_AMOUNT);
        let metadata = FA::get_metadata();

        assert!(
            primary_fungible_store::balance(buyer_addr, metadata) >= amount,
            EINSUFFICIENT_AMOUNT
        );

        create(buyer_addr, seller, amount, metadata);
    }

    entry fun release_escrow(buyer: &signer, escrow_id: u64) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);

        assert!(
            borrow_global<Vault>(@my_addrx).next_escrow_id > escrow_id, EID_NOT_FOUND
        );

        assert!(
            borrow_global<Vault>(@my_addrx).vault_owner.borrow(escrow_id)
                == &buyer_addr,
            EONLY_BUYER
        );

        release(escrow_id);
    }

    entry fun cancel_escrow(buyer: &signer, escrow_id: u64) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        assert!(
            borrow_global<Vault>(@my_addrx).next_escrow_id > escrow_id, EID_NOT_FOUND
        );

        assert!(
            borrow_global<Vault>(@my_addrx).vault_owner.borrow(escrow_id)
                == &buyer_addr,
            EONLY_BUYER
        );

        cancel(escrow_id);
    }

    #[view]
    public fun check_escrow(escrow_id: u64): (address, address, u64, bool) acquires Vault, Escrow {
        let vault = borrow_global<Vault>(@my_addrx);

        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);
        let escrow = borrow_global<Escrow>(buyer_signer_address);
        (escrow.buyer, escrow.seller, escrow.amount, escrow.released)
    }

    #[view]
    public fun get_next_escrow_id(): u64 acquires Vault {
        let vault = borrow_global<Vault>(@my_addrx);
        vault.next_escrow_id
    }

    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test(admin: &signer, alice: &signer, bob: &signer) acquires Vault, Escrow {

        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);
        FA::register(bob);

        FA::mint(admin, alice_addrx, 100);
        FA::mint(admin, bob_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 2);

        create_escrow(alice, bob_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, amount, released_) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(amount == 50, 7);
        assert!(released_ == false, 8);

        release_escrow(alice, 0);

        assert!(FA::check_balance(alice_addrx) == 50, 9);
        assert!(FA::check_balance(bob_addrx) == 150, 10);
        let (_, _, _, released_) = check_escrow(0);

        assert!(released_ == true, 9);
    }

    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test_cancel(admin: &signer, alice: &signer, bob: &signer) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);
        FA::register(bob);

        FA::mint(admin, alice_addrx, 100);
        FA::mint(admin, bob_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 2);

        create_escrow(alice, bob_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, amount, released_) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(amount == 50, 7);
        assert!(released_ == false, 8);

        cancel_escrow(alice, 0);

        assert!(FA::check_balance(alice_addrx) == 100, 9);
        assert!(FA::check_balance(bob_addrx) == 100, 10);

        let (_, _, _, released_) = check_escrow(0);

        assert!(released_ == true, 9);
    }

    #[expected_failure(abort_code = EALREADY_RELEASED)]
    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test_double_release(
        admin: &signer, alice: &signer, bob: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(alice, 0);
        release_escrow(alice, 0);
    }

    #[expected_failure(abort_code = EINSUFFICIENT_AMOUNT)]
    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun test_insufficient_amount(
        admin: &signer, alice: &signer, bob: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        create_escrow(alice, bob_addrx, 150);

    }

    #[expected_failure(abort_code = EONLY_BUYER)]
    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun non_buyer_release_fails(
        admin: &signer, alice: &signer, bob: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(bob, 0);
    }

    #[expected_failure(abort_code = EID_NOT_FOUND)]
    #[test(admin = @my_addrx, alice = @0x1, bob = @0x2)]
    fun release_nonexistent_id(
        admin: &signer, alice: &signer, bob: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(bob, 1);
    }

    #[expected_failure(abort_code = EINVALID_ADDRESS)]
    #[test(admin = @my_addrx, alice = @0x1)]
    fun create_escrow_with_same_buyer_seller(
        admin: &signer, alice: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, alice_addrx, 50);

    }
}

