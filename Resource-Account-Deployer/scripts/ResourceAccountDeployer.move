script {
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use my_addrx::NFT;

    fun deploy(deployer: &signer) {
        let seed = b"nft_minter";
        let (resource_signer, signer_cap) =
            account::create_resource_account(deployer, seed);

        NFT::init_module(resource_signer);
    }
}

