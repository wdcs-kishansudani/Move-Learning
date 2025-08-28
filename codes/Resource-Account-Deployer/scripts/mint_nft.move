script {
    use std::string;
    use my_addrx::NFT;

    const COLLECTION_NAME: vector<u8> = b"First NFT Collection";
    const COLLECTION_DESCRIPTION: vector<u8> = b"First NFT collection Description";

    fun main(account: &signer) {
        NFT::mint_nft(
            account,
            string::utf8(COLLECTION_NAME),
            string::utf8(b"First NFT"),
            string::utf8(b"First NFT Description")
        );
    }
}

