module my_addrx::Counter {
    use std::signer;
    use std::event;

    const EALREADY_EXISTS: u64 = 0;
    const EDOENT_EXISTS: u64 = 1;

    struct Counter has key {
        counter: u64
    }

    #[event]
    struct CounterIncremented has store, drop {
        current: u64
    }

    #[event]
    struct CounterDecremented has store, drop {
        current: u64
    }

    #[event]
    struct CounterInitialized has store, drop {
        by: address
    }

    public entry fun create_counter(account: &signer) {
        let addrx = signer::address_of(account);

        assert!(!exists<Counter>(addrx), EALREADY_EXISTS);

        move_to(account, Counter {
            counter: 0
        });

        event::emit(CounterInitialized {
            by: addrx
        });
    }

    public entry fun increment(account: &signer) acquires Counter {
        let addrx = signer::address_of(account);

        assert!(exists<Counter>(addrx), EDOENT_EXISTS);

        let counter = borrow_global_mut<Counter>(addrx);

        counter.counter += 1;

        event::emit(CounterIncremented {
            current: counter.counter
        });
    }

    public entry fun decrement(account: &signer) acquires Counter {
        let addrx = signer::address_of(account);

        assert!(exists<Counter>(addrx), EDOENT_EXISTS);

        let counter = borrow_global_mut<Counter>(addrx);

        counter.counter -= 1;

        event::emit(CounterDecremented {
            current: counter.counter
        });
    }

    public fun get_counter(account: address) : u64 acquires Counter {
        if (!exists<Counter>(account)) {
            0
        } else {
            borrow_global<Counter>(account).counter
        }
    }

    #[test_only]
    use aptos_framework::account;
    #[test]
    fun test_flow() acquires Counter {
        let alice = account::create_account_for_test(@0x1);
        let bob = account::create_account_for_test(@0x2);

        let alice_addrx = signer::address_of(&alice);
        let bob_addrx = signer::address_of(&bob);

        create_counter(&alice);
        assert!(get_counter(alice_addrx) == 0, 1);
        increment(&alice);
        assert!(get_counter(alice_addrx) == 1, 2);
        assert!(get_counter(bob_addrx) == 0, 3);
        create_counter(&bob);
        increment(&bob);
        assert!(get_counter(bob_addrx) == 1, 4);
    }
}