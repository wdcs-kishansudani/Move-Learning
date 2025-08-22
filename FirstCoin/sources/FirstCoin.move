module my_addrx::FirstCoin {
    use std::signer;

    struct FirstCoin {}

    fun init_module(admin: &signer) {
        aptos_framework::managed_coin::initialize<FirstCoin>(
            admin,
            b"First Coin",
            b"FST",
            8,
            false
        );

        let addrx = signer::address_of(admin);
        aptos_framework::managed_coin::register<FirstCoin>(admin);
        aptos_framework::managed_coin::mint<FirstCoin>(admin, addrx, 100 * 100_000_000);
    }
    
    #[test(framework = @aptos_framework, admin = @my_addrx)]
    fun test_flow(framework: &signer, admin: &signer) {
        let addrx = signer::address_of(admin);
        aptos_framework::coin::create_coin_conversion_map(framework);
        init_module(admin);

        let balance = aptos_framework::coin::balance<FirstCoin>(addrx);
        assert!(balance == 100 * 100_000_000, 1);
    }
}