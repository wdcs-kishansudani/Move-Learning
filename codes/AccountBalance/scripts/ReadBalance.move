script {
    use std::signer;
    use std::debug;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin;

    fun main(account: &signer) {
        let addrx = signer::address_of(account);

        let balance = coin::balance<aptos_coin::AptosCoin>(addrx);
        debug::print(&balance);
    }
}