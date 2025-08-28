module my_addrx::NFT {
    use std::signer;
    use std::option;
    use std::object::{Self, Object};
    use aptos_framework::account;
    use aptos_framework::string;
    use aptos_token_objects::token::{Self, Token};
    use aptos_token_objects::collection;
    use aptos_framework::resource_account;
    use aptos_framework::account::SignerCapability;

    const COLLECTION_NAME: vector<u8> = b"First NFT Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"First NFT collection Description";
    const MAX_SUPPLY: u64 = 1000;

    struct ModuleData has key {
        signer_cap: SignerCapability
    }

    fun init_module(resource_signer: &signer) {
        collection::create_fixed_collection(
            resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            MAX_SUPPLY,
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(b"https://mycollection.com")
        );

        let resource_signer_cap =
            resource_account::retrieve_resource_account_cap(resource_signer, @default);

        move_to(resource_signer, ModuleData { signer_cap: resource_signer_cap });
    }

    public entry fun mint_nft(
        receiver: &signer,
        collection_name: string::String,
        token_name: string::String,
        description: string::String
    ) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@my_addrx);
        let resource_signer =
            &account::create_signer_with_capability(&module_data.signer_cap);

        let royalty = option::none();
        let constructor_ref =
            token::create_named_token(
                resource_signer,
                collection_name,
                description,
                token_name,
                royalty,
                string::utf8(
                    b"https://mycollection.com/my-named-token.jpeg"
                )
            );

        let token: Object<Token> = object::object_from_constructor_ref(&constructor_ref);

        object::transfer(resource_signer, token, signer::address_of(receiver));

    }
}

