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
    const EONLY_ARBITRATOR: u64 = 9;
    const EINVALID_DISPUTOR: u64 = 10;
    const EINVALID_RELEASE_ADDRESS: u64 = 11;
    const EINVALID_DISPUTE: u64 = 12;
    const EESCROW_IN_DISPUTE: u64 = 13;

    struct Escrow has key {
        buyer: address,
        seller: address,
        token: Object<FungibleStore>,
        arbitrator: address,
        amount: u64,
        released: bool,
        state: u8 // 0=pending, 1=released, 2=canceled, 3=disputed, 4=resolved
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
        arbitrator: address,
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

        let escrow = Escrow {
            buyer,
            seller,
            token: fs,
            arbitrator,
            amount,
            released: false,
            state: 0
        };

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

    fun release(escrow_id: u64, stats: u8) acquires Vault, Escrow {
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
        escrow.state = stats;

        FA::transfer(escrow.token, seller_store, escrow.amount);
    }

    fun cancel(escrow_id: u64, stats: u8) acquires Vault, Escrow {
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
        escrow.state = stats;

        FA::transfer(escrow.token, buyer_store, escrow.amount);
    }

    entry fun create_escrow(
        buyer: &signer,
        seller: address,
        arbitrator: address,
        amount: u64
    ) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        assert!(buyer_addr != seller, EINVALID_ADDRESS);
        assert!(buyer_addr != arbitrator, EINVALID_ADDRESS);
        assert!(amount > 0, EINVALID_AMOUNT);
        let metadata = FA::get_metadata();

        assert!(
            primary_fungible_store::balance(buyer_addr, metadata) >= amount,
            EINSUFFICIENT_AMOUNT
        );

        create(
            buyer_addr,
            seller,
            arbitrator,
            amount,
            metadata
        );
    }

    entry fun release_escrow(buyer: &signer, escrow_id: u64) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        let vault = borrow_global<Vault>(@my_addrx);
        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);
        let escrow = borrow_global<Escrow>(*vault.vault.borrow(escrow_id));

        if (escrow.state != 0 && escrow.state == 3) {
            assert!(false, EESCROW_IN_DISPUTE);
        };

        assert!(
            vault.vault_owner.borrow(escrow_id) == &buyer_addr,
            EONLY_BUYER
        );

        release(escrow_id, 1);
    }

    entry fun cancel_escrow(buyer: &signer, escrow_id: u64) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        let vault = borrow_global<Vault>(@my_addrx);
        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);
        let escrow = borrow_global<Escrow>(*vault.vault.borrow(escrow_id));

        if (escrow.state != 0 && escrow.state == 3) {
            assert!(false, EESCROW_IN_DISPUTE);
        };

        assert!(
            vault.vault_owner.borrow(escrow_id) == &buyer_addr,
            EONLY_BUYER
        );

        cancel(escrow_id, 2);
    }

    entry fun dispute_escrow(account: &signer, escrow_id: u64) acquires Vault, Escrow {
        let addrx = signer::address_of(account);
        let vault = borrow_global<Vault>(@my_addrx);
        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);

        let escrow = borrow_global_mut<Escrow>(*vault.vault.borrow(escrow_id));

        if (escrow.state != 0 && escrow.state == 3) {
            assert!(false, EESCROW_IN_DISPUTE);
        };

        assert!(
            escrow.buyer == addrx || escrow.seller == addrx,
            EINVALID_DISPUTOR
        );

        escrow.state = 3;
    }

    entry fun resolve_dispute(
        arbitrator: &signer, to: address, escrow_id: u64
    ) acquires Vault, Escrow {
        let arbitrator_addrx = signer::address_of(arbitrator);
        assert!(
            borrow_global<Vault>(@my_addrx).next_escrow_id > escrow_id, EID_NOT_FOUND
        );

        let vault = borrow_global<Vault>(@my_addrx);
        let escrow = borrow_global<Escrow>(*vault.vault.borrow(escrow_id));

        assert!(escrow.state == 3, EINVALID_DISPUTE);

        assert!(
            escrow.arbitrator == arbitrator_addrx,
            EONLY_ARBITRATOR
        );

        assert!(
            to == escrow.buyer || to == escrow.seller,
            EINVALID_RELEASE_ADDRESS
        );

        if (to == escrow.buyer) {
            cancel(escrow_id, 4);
        } else {
            release(escrow_id, 4);
        };

    }

    #[view]
    public fun check_escrow(
        escrow_id: u64
    ): (address, address, address, u64, bool, u8) acquires Vault, Escrow {
        let vault = borrow_global<Vault>(@my_addrx);

        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);
        let escrow = borrow_global<Escrow>(buyer_signer_address);
        (
            escrow.buyer,
            escrow.seller,
            escrow.arbitrator,
            escrow.amount,
            escrow.released,
            escrow.state
        )
    }

    #[view]
    public fun get_next_escrow_id(): u64 acquires Vault {
        let vault = borrow_global<Vault>(@my_addrx);
        vault.next_escrow_id
    }

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {

        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);
        FA::register(bob);

        FA::mint(admin, alice_addrx, 100);
        FA::mint(admin, bob_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 2);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, arbitrator, amount, released_, stats) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(arbitrator == charlie_addrx, 7);
        assert!(amount == 50, 7);
        assert!(released_ == false, 8);
        assert!(stats == 0, 8);

        release_escrow(alice, 0);

        assert!(FA::check_balance(alice_addrx) == 50, 9);
        assert!(FA::check_balance(bob_addrx) == 150, 10);
        let (_, _, _, _, released_, state) = check_escrow(0);

        assert!(released_ == true, 9);
        assert!(state == 1, 9);
    }

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_cancel(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);
        FA::register(bob);

        FA::mint(admin, alice_addrx, 100);
        FA::mint(admin, bob_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 2);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, arbitrator, amount, released_, stats) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(arbitrator == charlie_addrx, 7);
        assert!(amount == 50, 7);
        assert!(released_ == false, 8);
        assert!(stats == 0, 8);

        cancel_escrow(alice, 0);

        assert!(FA::check_balance(alice_addrx) == 100, 9);
        assert!(FA::check_balance(bob_addrx) == 100, 10);

        let (_, _, _, _, released_, state) = check_escrow(0);

        assert!(released_ == true, 9);
        assert!(state == 2, 9);
    }

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_dispute(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);
        FA::register(bob);

        FA::mint(admin, alice_addrx, 100);
        FA::mint(admin, bob_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        dispute_escrow(alice, 0);

        let (_, _, _, _, released_, state) = check_escrow(0);

        assert!(released_ == false, 9);
        assert!(state == 3, 10);

        assert!(FA::check_balance(alice_addrx) == 50, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 1);

        resolve_dispute(charlie, alice_addrx, 0);
        let (_, _, _, _, released_, state) = check_escrow(0);
        assert!(released_ == true, 9);
        assert!(state == 4, 10);
        assert!(FA::check_balance(alice_addrx) == 100, 1);
        assert!(FA::check_balance(bob_addrx) == 100, 1);

    }

    #[expected_failure(abort_code = EALREADY_RELEASED)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_double_release(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(alice, 0);
        release_escrow(alice, 0);
    }

    #[expected_failure(abort_code = EINSUFFICIENT_AMOUNT)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_insufficient_amount(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        create_escrow(alice, bob_addrx, charlie_addrx, 150);

    }

    #[expected_failure(abort_code = EONLY_BUYER)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun non_buyer_release_fails(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(bob, 0);
    }

    #[expected_failure(abort_code = EID_NOT_FOUND)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun release_nonexistent_id(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        release_escrow(bob, 1);
    }

    #[expected_failure(abort_code = EINVALID_ADDRESS)]
    #[test(admin = @my_addrx, alice = @0x1, charlie = @0x3)]
    fun create_escrow_with_same_buyer_seller(
        admin: &signer, alice: &signer, charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, alice_addrx, charlie_addrx, 50);

    }

    #[expected_failure(abort_code = EONLY_ARBITRATOR)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_not_aribitrator(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        dispute_escrow(alice, 0);

        resolve_dispute(alice, alice_addrx, 0);

    }

    #[expected_failure(abort_code = EINVALID_DISPUTOR)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_invalid_disputor(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        dispute_escrow(charlie, 0);

    }

    #[expected_failure(abort_code = EINVALID_RELEASE_ADDRESS)]
    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_invalid_release_address(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(alice, bob_addrx, charlie_addrx, 50);

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        dispute_escrow(alice, 0);
        resolve_dispute(charlie, charlie_addrx, 0);

    }
}

