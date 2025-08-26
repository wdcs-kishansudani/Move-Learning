module my_addrx::HelloMove {
    use std::signer;
    use std::event;

    const EALREADY_INITIALIED: u64 = 0;

    struct Message has key {
        msg: vector<u8>
    }

    #[event]
    struct MessageSet has store, drop {
        msg: vector<u8>
    }

    fun init_module(admin: &signer) {
        let addrx = signer::address_of(admin);
        assert!(!exists<Message>(addrx), EALREADY_INITIALIED);

        let msg = b"Hello, Move!";
        move_to(admin, Message {
            msg
        });
    }

    public entry fun set_message(message : vector<u8>) acquires Message {
        let storage = @my_addrx;

        let msg = borrow_global_mut<Message>(storage);
        msg.msg = message;

        event::emit(MessageSet {
            msg: message
        });
    }

    public fun get_message() : vector<u8> acquires Message {
        let storage = @my_addrx;

        borrow_global<Message>(storage).msg
    }

    #[test(admin = @my_addrx)]
    fun test_flow(admin: &signer) acquires Message {
        init_module(admin);

        let message = b"Welcome to Aptos";
        set_message(message);

        assert!(message == get_message(), 1);
    }
}