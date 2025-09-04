module my_addrx::Escrow {
    use std::signer;
    use std::object::{Self, Object, ExtendRef};
    use std::timestamp;
    use aptos_framework::fungible_asset::Metadata;
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
    const ENOT_ENOUGH_TIME_PASSED: u64 = 14;

    const ESCROW_TIMEOUT: u64 = 86400; // 1 Day

    struct Escrow has key {
        buyer: address,
        seller: address,
        arbitrator: address,
        amount: u64,
        created_at: u64,
        state: u8, // 0=pending, 1=released, 2=canceled, 3=disputed, 4=resolved
        extended_ref: ExtendRef
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
        buyer: &signer,
        seller: address,
        arbitrator: address,
        amount: u64,
        metadata: Object<Metadata>
    ) acquires Vault, Escrow {
        let buyer_addrx = signer::address_of(buyer);
        assert!(
            primary_fungible_store::primary_store_exists(buyer_addrx, metadata),
            EPRIMARY_STORE_NOT_EXIST
        );

        let constructor_ref = &object::create_object(buyer_addrx);

        let escrow = Escrow {
            buyer: buyer_addrx,
            seller,
            arbitrator,
            amount,
            created_at: timestamp::now_seconds(),
            state: 0,
            extended_ref: object::generate_extend_ref(constructor_ref)
        };

        let vault = borrow_global_mut<Vault>(@my_addrx);

        let object_signer = &object::generate_signer(constructor_ref);
        move_to(object_signer, escrow);

        let next_escrow_id = vault.next_escrow_id;
        vault.vault.add(next_escrow_id, signer::address_of(object_signer));
        vault.vault_owner.add(next_escrow_id, buyer_addrx);

        vault.next_escrow_id += 1;

        let es = borrow_global<Escrow>(signer::address_of(object_signer));

        primary_fungible_store::transfer(
            buyer,
            metadata,
            signer::address_of(object_signer),
            es.amount
        );
    }

    fun release(escrow_id: u64, metadata: Object<Metadata>) acquires Vault, Escrow {
        let vault = borrow_global_mut<Vault>(@my_addrx);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);

        let escrow = borrow_global_mut<Escrow>(buyer_signer_address);

        assert!(escrow.state == 0, EALREADY_RELEASED);

        if (!primary_fungible_store::primary_store_exists(escrow.seller, metadata)) {
            primary_fungible_store::create_primary_store(escrow.seller, metadata);
        };

        escrow.state = 1;

        primary_fungible_store::transfer(
            &object::generate_signer_for_extending(&escrow.extended_ref),
            metadata,
            escrow.seller,
            escrow.amount
        );
    }

    fun cancel(escrow_id: u64, metadata: Object<Metadata>) acquires Vault, Escrow {
        let vault = borrow_global_mut<Vault>(@my_addrx);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);

        let escrow = borrow_global_mut<Escrow>(buyer_signer_address);

        assert!(escrow.state == 0, EALREADY_RELEASED);

        escrow.state = 2;

        primary_fungible_store::transfer(
            &object::generate_signer_for_extending(&escrow.extended_ref),
            metadata,
            escrow.buyer,
            escrow.amount
        );

    }

    entry fun create_escrow(
        buyer: &signer,
        seller: address,
        arbitrator: address,
        metadata: Object<Metadata>,
        amount: u64
    ) acquires Vault, Escrow {
        let buyer_addr = signer::address_of(buyer);
        assert!(buyer_addr != seller, EINVALID_ADDRESS);
        assert!(buyer_addr != arbitrator, EINVALID_ADDRESS);
        assert!(amount > 0, EINVALID_AMOUNT);

        assert!(
            primary_fungible_store::balance(buyer_addr, metadata) >= amount,
            EINSUFFICIENT_AMOUNT
        );

        create(buyer, seller, arbitrator, amount, metadata);
    }

    entry fun release_escrow(
        buyer: &signer, metadata: Object<Metadata>, escrow_id: u64
    ) acquires Vault, Escrow {
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

        release(escrow_id, metadata);
    }

    entry fun cancel_escrow(
        buyer: &signer, metadata: Object<Metadata>, escrow_id: u64
    ) acquires Vault, Escrow {
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

        cancel(escrow_id, metadata);
    }

    entry fun dispute_escrow(account: &signer, escrow_id: u64) acquires Vault, Escrow {
        let addrx = signer::address_of(account);
        let vault = borrow_global<Vault>(@my_addrx);
        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);

        let escrow = borrow_global_mut<Escrow>(*vault.vault.borrow(escrow_id));

        assert!(
            escrow.created_at + ESCROW_TIMEOUT < timestamp::now_seconds(),
            ENOT_ENOUGH_TIME_PASSED
        );

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
        arbitrator: &signer,
        to: address,
        metadata: Object<Metadata>,
        escrow_id: u64
    ) acquires Vault, Escrow {
        let arbitrator_addrx = signer::address_of(arbitrator);
        assert!(
            borrow_global<Vault>(@my_addrx).next_escrow_id > escrow_id, EID_NOT_FOUND
        );

        let vault = borrow_global<Vault>(@my_addrx);
        let escrow = borrow_global_mut<Escrow>(*vault.vault.borrow(escrow_id));

        assert!(escrow.state == 3, EINVALID_DISPUTE);

        assert!(
            escrow.arbitrator == arbitrator_addrx,
            EONLY_ARBITRATOR
        );

        assert!(
            to == escrow.buyer || to == escrow.seller,
            EINVALID_RELEASE_ADDRESS
        );

        escrow.state = 4;
        primary_fungible_store::transfer(
            &object::generate_signer_for_extending(&escrow.extended_ref),
            metadata,
            to,
            escrow.amount
        );
    }

    #[view]
    public fun check_escrow(escrow_id: u64): (address, address, address, u64, u8) acquires Vault, Escrow {
        let vault = borrow_global<Vault>(@my_addrx);

        assert!(vault.next_escrow_id > escrow_id, EID_NOT_FOUND);

        let buyer_signer_address = *vault.vault.borrow(escrow_id);
        let escrow = borrow_global<Escrow>(buyer_signer_address);
        (escrow.buyer, escrow.seller, escrow.arbitrator, escrow.amount, escrow.state)
    }

    #[view]
    public fun get_next_escrow_id(): u64 acquires Vault {
        let vault = borrow_global<Vault>(@my_addrx);
        vault.next_escrow_id
    }

    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);

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

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, arbitrator, amount, stats) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(arbitrator == charlie_addrx, 7);
        assert!(amount == 50, 8);
        assert!(stats == 0, 9);

        release_escrow(alice, FA::get_metadata(), 0);

        assert!(FA::check_balance(alice_addrx) == 50, 10);
        assert!(FA::check_balance(bob_addrx) == 150, 11);
        let (_, _, _, _, state) = check_escrow(0);

        assert!(state == 1, 12);
    }

    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_cancel(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
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

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 3);
        assert!(FA::check_balance(bob_addrx) == 100, 4);

        let (buyer, seller, arbitrator, amount, stats) = check_escrow(0);
        assert!(buyer == alice_addrx, 5);
        assert!(seller == bob_addrx, 6);
        assert!(arbitrator == charlie_addrx, 7);
        assert!(amount == 50, 8);
        assert!(stats == 0, 9);

        cancel_escrow(alice, FA::get_metadata(), 0);

        assert!(FA::check_balance(alice_addrx) == 100, 10);
        assert!(FA::check_balance(bob_addrx) == 100, 11);

        let (_, _, _, _, state) = check_escrow(0);

        assert!(state == 2, 12);
    }

    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_dispute(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
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

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 3);

        timestamp::fast_forward_seconds(86500);
        dispute_escrow(alice, 0);

        let (_, _, _, _, state) = check_escrow(0);

        assert!(state == 3, 4);

        assert!(FA::check_balance(alice_addrx) == 50, 5);
        assert!(FA::check_balance(bob_addrx) == 100, 6);

        resolve_dispute(charlie, alice_addrx, FA::get_metadata(), 0);
        let (_, _, _, _, state) = check_escrow(0);
        assert!(state == 4, 7);
        assert!(FA::check_balance(alice_addrx) == 100, 8);
        assert!(FA::check_balance(bob_addrx) == 100, 9);

    }

    #[expected_failure(abort_code = EALREADY_RELEASED)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_double_release(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);

        release_escrow(alice, FA::get_metadata(), 0);
        release_escrow(alice, FA::get_metadata(), 0);
    }

    #[expected_failure(abort_code = EINSUFFICIENT_AMOUNT)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_insufficient_amount(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            150
        );

    }

    #[expected_failure(abort_code = EONLY_BUYER)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun non_buyer_release_fails(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);

        release_escrow(bob, FA::get_metadata(), 0);
    }

    #[expected_failure(abort_code = EID_NOT_FOUND)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun release_nonexistent_id(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);

        release_escrow(bob, FA::get_metadata(), 1);
    }

    #[expected_failure(abort_code = EINVALID_ADDRESS)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, charlie = @0x3
    )]
    fun create_escrow_with_same_buyer_seller(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            alice_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

    }

    #[expected_failure(abort_code = EONLY_ARBITRATOR)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_not_aribitrator(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);

        timestamp::fast_forward_seconds(86500);
        dispute_escrow(alice, 0);

        resolve_dispute(alice, alice_addrx, FA::get_metadata(), 0);

    }

    #[expected_failure(abort_code = EINVALID_DISPUTOR)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_invalid_disputor(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);

        timestamp::fast_forward_seconds(86500);
        dispute_escrow(charlie, 0);

    }

    #[expected_failure(abort_code = EINVALID_RELEASE_ADDRESS)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_invalid_release_address(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);
        timestamp::fast_forward_seconds(86500);
        dispute_escrow(alice, 0);
        resolve_dispute(charlie, charlie_addrx, FA::get_metadata(), 0);

    }

    #[expected_failure(abort_code = ENOT_ENOUGH_TIME_PASSED)]
    #[test(
        framework = @0x1, admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    fun test_not_enough_time_passed_for_dispute(
        framework: &signer,
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires Vault, Escrow {
        timestamp::set_time_has_started_for_testing(framework);
        let alice_addrx = signer::address_of(alice);
        let bob_addrx = signer::address_of(bob);
        let charlie_addrx = signer::address_of(charlie);

        FA::test_init(admin);
        init_module(admin);

        FA::register(alice);

        FA::mint(admin, alice_addrx, 100);

        assert!(FA::check_balance(alice_addrx) == 100, 1);

        create_escrow(
            alice,
            bob_addrx,
            charlie_addrx,
            FA::get_metadata(),
            50
        );

        assert!(FA::check_balance(alice_addrx) == 50, 2);
        timestamp::fast_forward_seconds(86300);
        dispute_escrow(alice, 0);

    }
}

