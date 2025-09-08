module my_addrx::Swap {
    use std::signer;
    use std::object;
    use std::option::{Self, Option};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_std::type_info::{Self, TypeInfo};
    use aptos_framework::smart_table::{Self, SmartTable};

    const EALREADY_REGISTERED: u64 = 1;
    const ENOT_REGISTERED: u64 = 2;
    const EMODULE_NOT_INITIALIZED: u64 = 3;
    const E_RESOURCE_NOT_FOUND: u64 = 4;
    const E_NOT_AUTHORIZED: u64 = 5;
    const E_NAME_ALREADY_EXISTS: u64 = 6;
    const ESWAP_NOT_INITIALIZED: u64 = 7;
    const ENOT_IN_CREATED_STATS: u64 = 8;
    const E_ALREADY_APPROVED: u64 = 9;
    const E_ALREADY_RESOLVED_DISPUTE: u64 = 10;
    const EALREADY_RELEASED: u64 = 11;
    const ENOT_IN_DISPUTED_STATS: u64 = 12;
    const E_INVALID_REFUND: u64 = 13;

    const SEED: vector<u8> = b"THIS IS EPIC SWAP SEED!!";

    struct Swap<phantom T, phantom U> has key {
        resource1: Option<ResourceInfo<T>>,
        resource2: Option<ResourceInfo<U>>,
        arbitrator: address,
        resource1_state: u8, // 0=pending, 1=approved, 2=request_cancel, 3=disputed, 4=resolved
        resource2_state: u8, // 0=pending, 1=approved, 2=request_cancel, 3=disputed, 4=resolved
        state: u8, // 0=creation_pending, 1=created, 2=release_pending, 3=released, 4=canceled, 5=disputed
        refund: u8, // 0=initial, 1=no_refund, 2=refund_approved
        uid: u64
    }

    struct ResourceInfo<phantom T> has copy, store, drop {
        owner: address,
        typer_info: TypeInfo
    }

    struct System has key {
        counter: u64,
        resource_cap: SignerCapability,
        resource_addrx: address,
        vault_addrx: SmartTable<u64, address>
    }

    fun init_module(admin: &signer) {

        let (resource_signer, resource_cap) =
            account::create_resource_account(admin, SEED);

        move_to(
            &resource_signer,
            System {
                counter: 0,
                resource_cap,
                resource_addrx: signer::address_of(&resource_signer),
                vault_addrx: smart_table::new<u64, address>()
            }
        );
    }

    public fun register_resource<T, U>(
        resource1: ResourceInfo<T>, resource2: ResourceInfo<U>, arbitrator: address
    ) acquires System {
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        let constructor_ref = &object::create_object(sys.resource_addrx);
        let resource_signer = &object::generate_signer(constructor_ref);

        move_to(
            resource_signer,
            Swap<T, U> {
                resource1: option::some(resource1),
                resource2: option::some(resource2),
                arbitrator: arbitrator,
                resource1_state: 0,
                resource2_state: 0,
                state: 1,
                refund: 0,
                uid: sys.counter
            }
        );

        sys.vault_addrx.add(
            sys.counter, object::address_from_constructor_ref(constructor_ref)
        );
        sys.counter += 1;
    }

    public fun approve_resource_release<T, U>(user: &signer, uid: u64) acquires System, Swap {
        let user_addr = signer::address_of(user);
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        assert!(sys.vault_addrx.contains(uid), E_RESOURCE_NOT_FOUND);

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(swap.state == 1, EALREADY_REGISTERED);

        assert!(
            swap.resource1.is_some() && swap.resource2.is_some(),
            ESWAP_NOT_INITIALIZED
        );

        assert!(
            swap.resource1.borrow().owner == user_addr
                || swap.resource2.borrow().owner == user_addr,
            E_NOT_AUTHORIZED
        );

        if (swap.resource1.borrow().owner == user_addr) {
            swap.resource1_state = 1;
        } else {
            swap.resource2_state = 1;
        };

        if (swap.resource1_state == 1 && swap.resource2_state == 1) {
            swap.state = 2;
        };
    }

    public fun request_cancel<T, U>(user: &signer, uid: u64) acquires System, Swap {
        let user_addr = signer::address_of(user);
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        assert!(sys.vault_addrx.contains(uid), E_RESOURCE_NOT_FOUND);

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(swap.state == 1, ENOT_IN_CREATED_STATS);

        assert!(
            swap.resource1.is_some() && swap.resource2.is_some(),
            ESWAP_NOT_INITIALIZED
        );

        assert!(
            swap.resource1.borrow().owner == user_addr
                || swap.resource2.borrow().owner == user_addr,
            E_NOT_AUTHORIZED
        );

        if (swap.resource1.borrow().owner == user_addr) {
            swap.resource1_state = 2;
        } else {
            swap.resource2_state = 2;
        };

        if (swap.resource1_state == 2 && swap.resource2_state == 2) {
            swap.state = 4;
        };
    }

    public fun dispute<T, U>(user: &signer, uid: u64) acquires System, Swap {
        let user_addr = signer::address_of(user);
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        assert!(sys.vault_addrx.contains(uid), E_RESOURCE_NOT_FOUND);

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(swap.state == 1, ENOT_IN_CREATED_STATS);

        assert!(
            swap.resource1.borrow().owner == user_addr
                || swap.resource2.borrow().owner == user_addr,
            E_NOT_AUTHORIZED
        );

        if (swap.resource1_state == 1 && swap.resource2_state == 1) {
            assert!(false, E_ALREADY_APPROVED);
        } else if (swap.resource1_state == 4 && swap.resource2_state == 4) {
            assert!(false, E_ALREADY_RESOLVED_DISPUTE);
        };

        if (swap.resource1.borrow().owner == user_addr) {
            swap.resource1_state = 3;
        } else {
            swap.resource2_state = 3;
        };

        swap.state = 5;

    }

    public fun resolve_dispute_from_user<T, U>(user: &signer, uid: u64) acquires System, Swap {
        let user_addr = signer::address_of(user);
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(swap.state == 5, ENOT_IN_CREATED_STATS);

        assert!(
            swap.resource1.borrow().owner == user_addr
                || swap.resource2.borrow().owner == user_addr,
            E_NOT_AUTHORIZED
        );

        if (swap.resource1.borrow().owner == user_addr) {
            swap.resource1_state = 4;
        } else {
            swap.resource2_state = 4;
        };

        if (swap.resource1_state == 4 && swap.resource2_state == 4) {
            swap.state = 2;
        };
    }

    public fun resolve_dispute<T, U>(user: &signer, uid: u64, refund: u8) acquires System, Swap {
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(swap.state == 5, ENOT_IN_DISPUTED_STATS);

        assert!(
            swap.arbitrator == signer::address_of(user),
            E_NOT_AUTHORIZED
        );

        assert!(refund > 0 && refund <= 2, E_INVALID_REFUND);

        if (refund == 0) {
            swap.refund = 0;
            swap.state = 2;
        } else if (refund == 1) {
            swap.refund = 1;
            swap.state = 2;
        } else if (refund == 2) {
            swap.refund = 2;
            swap.state = 4;
        };

        swap.resource1_state = 4;
        swap.resource2_state = 4;
    }

    public fun release_resource<T, U>(user: &signer, uid: u64) acquires System, Swap {
        let user_addr = signer::address_of(user);
        let sys = borrow_global_mut<System>(get_resource_account_address(@my_addrx));

        assert!(sys.vault_addrx.contains(uid), E_RESOURCE_NOT_FOUND);

        let swap = borrow_global_mut<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        assert!(
            swap.state == 4 || swap.state == 2,
            ENOT_IN_CREATED_STATS
        );

        assert!(
            swap.resource1.borrow().owner == user_addr
                || swap.resource2.borrow().owner == user_addr,
            E_NOT_AUTHORIZED
        );

        swap.resource1_state = 4;
        swap.resource2_state = 4;

        swap.state = 3;
    }

    #[view]
    public fun get_swap<T, U>(
        uid: u64
    ): (ResourceInfo<T>, ResourceInfo<U>, address, u8, u8, u8, u8, u64) acquires System, Swap {
        let sys = borrow_global<System>(get_resource_account_address(@my_addrx));
        let swap = borrow_global<Swap<T, U>>(*sys.vault_addrx.borrow(uid));

        (
            *swap.resource1.borrow(),
            *swap.resource2.borrow(),
            swap.arbitrator,
            swap.resource1_state,
            swap.resource2_state,
            swap.state,
            swap.refund,
            swap.uid
        )
    }

    #[view]
    public fun get_resource_account_address(admin: address): address {
        account::create_resource_address(&admin, SEED)
    }

    #[test_only]
    struct TypeT {}

    struct TypeU {}

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    public fun test_swap_approve_and_dispute_with_resolve_from_arbitrator(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires System, Swap {
        init_module(admin);

        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        let charlie_addr = signer::address_of(charlie);

        let resource1 = ResourceInfo<TypeT> {
            owner: alice_addr,
            typer_info: type_info::type_of<TypeT>()
        };

        let resource2 = ResourceInfo<TypeU> {
            owner: bob_addr,
            typer_info: type_info::type_of<TypeU>()
        };

        register_resource<TypeT, TypeU>(resource1, resource2, charlie_addr);

        let (
            resource1,
            resource2,
            arbitrator,
            resource1_state,
            resource2_state,
            state,
            refund,
            uid
        ) = get_swap<TypeT, TypeU>(0);

        assert!(resource1.owner == alice_addr, 1);
        assert!(resource2.owner == bob_addr, 2);
        assert!(arbitrator == charlie_addr, 3);
        assert!(resource1_state == 0, 4);
        assert!(resource2_state == 0, 5);
        assert!(state == 1, 6);
        assert!(uid == 0, 7);
        assert!(refund == 0, 8);
        assert!(state == 1, 9);

        approve_resource_release<TypeT, TypeU>(alice, 0);
        let (_, _, _, resource1_state, _, _, _, _) = get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 1, 10);
        dispute<TypeT, TypeU>(bob, 0);

        resolve_dispute<TypeT, TypeU>(charlie, 0, 1);
        let (_, _, _, _, _, state, _, _) = get_swap<TypeT, TypeU>(0);

        assert!(state == 2, 11);

        release_resource<TypeT, TypeU>(alice, 0);
        let (_, _, _, resource1_state, resource2_state, state, refund, uid) =
            get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 4, 12);
        assert!(resource2_state == 4, 13);
        assert!(state == 3, 14);
        assert!(refund == 1, 15);
        assert!(uid == 0, 16);
    }

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    public fun test_swap_approve_and_dispute_with_resolve_from_user(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires System, Swap {
        init_module(admin);

        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        let charlie_addr = signer::address_of(charlie);

        let resource1 = ResourceInfo<TypeT> {
            owner: alice_addr,
            typer_info: type_info::type_of<TypeT>()
        };

        let resource2 = ResourceInfo<TypeU> {
            owner: bob_addr,
            typer_info: type_info::type_of<TypeU>()
        };

        register_resource<TypeT, TypeU>(resource1, resource2, charlie_addr);

        let (
            resource1,
            resource2,
            arbitrator,
            resource1_state,
            resource2_state,
            state,
            refund,
            uid
        ) = get_swap<TypeT, TypeU>(0);

        assert!(resource1.owner == alice_addr, 1);
        assert!(resource2.owner == bob_addr, 2);
        assert!(arbitrator == charlie_addr, 3);
        assert!(resource1_state == 0, 4);
        assert!(resource2_state == 0, 5);
        assert!(state == 1, 6);
        assert!(uid == 0, 7);
        assert!(refund == 0, 8);
        assert!(state == 1, 9);

        approve_resource_release<TypeT, TypeU>(alice, 0);
        let (_, _, _, resource1_state, _, _, _, _) = get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 1, 10);
        dispute<TypeT, TypeU>(bob, 0);

        resolve_dispute_from_user<TypeT, TypeU>(alice, 0);
        resolve_dispute_from_user<TypeT, TypeU>(bob, 0);

        let (_, _, _, resource_one_state, resource_two_state, state, _, _) =
            get_swap<TypeT, TypeU>(0);

        assert!(resource_one_state == 4, 11);
        assert!(resource_two_state == 4, 12);
        assert!(state == 2, 13);

        release_resource<TypeT, TypeU>(alice, 0);
        let (_, _, _, resource1_state, resource2_state, state, refund, uid) =
            get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 4, 14);
        assert!(resource2_state == 4, 15);
        assert!(state == 3, 16);
        assert!(refund == 0, 17);
        assert!(uid == 0, 18);

    }

    #[test(
        admin = @my_addrx, alice = @0x1, bob = @0x2, charlie = @0x3
    )]
    public fun test_swap_cancel(
        admin: &signer,
        alice: &signer,
        bob: &signer,
        charlie: &signer
    ) acquires System, Swap {
        init_module(admin);

        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);
        let charlie_addr = signer::address_of(charlie);

        let resource1 = ResourceInfo<TypeT> {
            owner: alice_addr,
            typer_info: type_info::type_of<TypeT>()
        };

        let resource2 = ResourceInfo<TypeU> {
            owner: bob_addr,
            typer_info: type_info::type_of<TypeU>()
        };

        register_resource<TypeT, TypeU>(resource1, resource2, charlie_addr);

        request_cancel<TypeT, TypeU>(alice, 0);

        request_cancel<TypeT, TypeU>(bob, 0);

        let (_, _, _, resource1_state, resource2_state, state, _, uid) =
            get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 2, 4);
        assert!(resource2_state == 2, 5);
        assert!(state == 4, 6);
        assert!(uid == 0, 7);

        release_resource<TypeT, TypeU>(alice, 0);
        let (_, _, _, resource1_state, resource2_state, state, refund, uid) =
            get_swap<TypeT, TypeU>(0);

        assert!(resource1_state == 4, 8);
        assert!(resource2_state == 4, 9);
        assert!(state == 3, 10);
        assert!(refund == 0, 11);
        assert!(uid == 0, 12);
    }
}

