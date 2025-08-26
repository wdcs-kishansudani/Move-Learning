module my_addrx::NESTEDOBJ {
    use std::signer;
    use std::string::{Self, String};
    use std::option;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token::{Self, Token};

    const EMODULE_ALREADY_INITIALIED: u64 = 0;

    const COLLECTION_NAME: vector<u8> = b"";
    const MAX_SUPPLY: u64 = 1000;
    const SEED: vector<u8> = b"SEED";

    struct TokenHolder has store, key {}

    struct Collector has key {
        holder: Object<TokenHolder>
    }

    struct Caps has key {
        collection_cap: SignerCapability
    }

    fun init_module(admin: &signer) {
        let (collection_signer, collection_cap) =
            account::create_resource_account(admin, SEED);
        collection::create_fixed_collection(
            &collection_signer,
            string::utf8(b""),
            MAX_SUPPLY,
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(b"")
        );

        move_to(admin, Caps { collection_cap: collection_cap });
    }

    public entry fun mint_nft(user: &signer, token_name: String) acquires Caps {
        let collection_cap = &borrow_global<Caps>(@my_addrx).collection_cap;

        let creator = &account::create_signer_with_capability(collection_cap);

        let ref =
            token::create_named_token(
                creator,
                string::utf8(COLLECTION_NAME),
                string::utf8(b"This is token and I love it!!"),
                token_name,
                option::none(),
                string::utf8(b"")
            );

        let token: Object<Token> = object::object_from_constructor_ref(&ref);

        object::transfer(creator, token, signer::address_of(user));
    }

    public entry fun add_to_obj(user: &signer, token_name: String) acquires Collector, Caps {
        let addrx = signer::address_of(user);

        if (!exists<Collector>(addrx)) {
            let ref = object::create_named_object(user, b"Collector");

            let obj_signer = object::generate_signer(&ref);
            move_to(&obj_signer, TokenHolder {});

            let obj = object::object_from_constructor_ref<TokenHolder>(&ref);

            move_to(user, Collector { holder: obj });
        };

        let token_addr =
            token::create_token_address(
                &get_creator_address(), &string::utf8(COLLECTION_NAME), &token_name
            );
        let token_obj: Object<Token> = object::address_to_object(token_addr);

        let main_obj = borrow_global<Collector>(addrx);

        object::transfer_to_object(user, token_obj, main_obj.holder);
    }

    #[view]
    public fun get_creator_address(): address acquires Caps {
        signer::address_of(
            &account::create_signer_with_capability(
                &borrow_global<Caps>(@my_addrx).collection_cap
            )
        )
    }

    #[test(admin = @my_addrx)]
    public fun test_flow(admin: &signer) acquires Collector, Caps {
        init_module(admin);

        // ############ TOKEN 1 ##############

        let collection_name = string::utf8(COLLECTION_NAME);
        let token_name_1 = string::utf8(b"First NFT");
        let nft_description = string::utf8(b"This is token and I love it!!");

        let alice = &aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(alice);

        mint_nft(alice, token_name_1);

        let creator_address = get_creator_address();

        let token_addr =
            token::create_token_address(
                &creator_address, &collection_name, &token_name_1
            );

        let token_1 = object::address_to_object<Token>(token_addr);

        assert!(token::name(token_1) == token_name_1, 1);
        assert!(token::description(token_1) == nft_description, 2);

        add_to_obj(alice, token_name_1);

        assert!(object::owns(token_1, alice_addrx), 3);

        // ############ TOKEN 2 ##############

        let token_name_2 = string::utf8(b"First NFT#1");
        mint_nft(alice, token_name_2);
        let token_addr =
            token::create_token_address(
                &creator_address, &collection_name, &token_name_2
            );

        let token_2 = object::address_to_object<Token>(token_addr);

        add_to_obj(alice, token_name_2);

        assert!(token::name(token_2) == token_name_2, 4);
        assert!(token::description(token_2) == nft_description, 5);
        assert!(object::owns(token_2, alice_addrx), 6);

        let bob = &aptos_framework::account::create_account_for_test(@0x3);
        let bob_addrx = signer::address_of(bob);

        let main_obj = borrow_global<Collector>(alice_addrx).holder;
        object::transfer(alice, main_obj, bob_addrx);
        assert!(object::owns(token_1, bob_addrx), 7);
        assert!(object::owns(token_2, bob_addrx), 8);
    }
}

