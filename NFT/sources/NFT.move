module my_addrx::NFT {
    use std::signer;
    use std::option;
    use aptos_framework::string;
    use aptos_token_objects::token::{Self, Token};
    use aptos_token_objects::collection;
    use aptos_framework::object;

    fun init_module(admin: &signer) {
        let collection_name = string::utf8(b"First NFT Collection");
        let collection_description = string::utf8(b"First NFT Collection");

        let max_supply = 1000;
        let royalty = option::none();

        collection::create_fixed_collection(
            admin,
            collection_description,
            max_supply,
            collection_name,
            royalty,
            string::utf8(b"https://mycollection.com")
        );

    }

    public entry fun mint_nft(
        creator: &signer,
        collection_name: string::String,
        token_name: string::String,
        description: string::String
    ) {
        let royalty = option::none();
        token::create_named_token(
            creator,
            collection_name,
            description,
            token_name,
            royalty,
            string::utf8(
                b"https://mycollection.com/my-named-token.jpeg"
            )
        );
    }

    #[test(admin = @my_addrx)]
    public fun test_flow(admin: &signer) {
        init_module(admin);

        let collection_name = string::utf8(b"First NFT Collection");
        let token_name = string::utf8(b"First NFT");
        let nft_description = string::utf8(b"First NFT Description");

        mint_nft(
            admin,
            collection_name,
            token_name,
            nft_description
        );

        let token_addr =
            token::create_token_address(
                &signer::address_of(admin), &collection_name, &token_name
            );

        let token = object::address_to_object<Token>(token_addr);

        assert!(token::name(token) == token_name);
        assert!(token::description(token) == nft_description);
    }
}

