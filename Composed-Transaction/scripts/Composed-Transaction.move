script {
    use std::signer;
    use std::debug;
    use my_addrx::FirstCoin;
    use my_addrx::Vault;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin;

    fun main(admin: &signer) {
        let addrx = signer::address_of(admin);

        let balance = coin::balance<aptos_coin::AptosCoin>(addrx);
        debug::print(&balance);

        aptos_framework::coin::transfer<FirstCoin::FirstCoin>(admin, addrx, 50 * 100_000_000);
        let my_addrx_balance = aptos_framework::coin::balance<FirstCoin::FirstCoin>(addrx);

        assert!(my_addrx_balance == 50 * 100_000_000, 2);

        Vault::register(admin);

        assert!(Vault::get_vault_balance(addrx) == 0, 4);
        Vault::deposit(admin, 50);
        assert!(Vault::get_vault_balance(addrx) == 50, 5);
    }
}