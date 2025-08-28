module my_addrx::my_module {
    use std::signer;
    use std::vector;

    struct Message has key {
        message: vector<u8>
    }

    public entry fun set_message(user: &signer, message: vector<u8>) acquires Message {
        let addrx = signer::address_of(user);
        if(!exists<Message>(addrx)) {
            move_to(user, Message {
                message: vector::empty(),
            });
        };

        let msg = borrow_global_mut<Message>(addrx);
        msg.message = message;
    }

    #[view]
    public fun get_message(addr: address): vector<u8> acquires Message {
        borrow_global<Message>(addr).message
    }
}

