module my_addrx::NFT {
    use std::signer;
    use std::option;
    use aptos_framework::string;
    use aptos_token_objects::token::{Self, Token};
    use aptos_token_objects::collection;
    use aptos_framework::object;
    use aptos_framework::resource_account;

    const COLLECTION_NAME: vector<u8> = b"First NFT Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"First NFT collection Description";
    const MAX_SUPPLY: u64 = 1000;

    fun init_module(resource_signer: &signer) {
        let resource_addr = signer::address_of(resource_signer);

        collection::create_fixed_collection(
            resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            MAX_SUPPLY,
            string::utf8(COLLECTION_NAME),
            option::none(),
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
}

