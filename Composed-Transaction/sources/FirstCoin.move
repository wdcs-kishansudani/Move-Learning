module my_addrx::FirstCoin {
    use std::signer;

    const E_ALREADY_EXIST: u64 = 0;

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

    public fun deploy(admin: &signer) {
        assert!(!aptos_framework::coin::is_coin_initialized<FirstCoin>(), E_ALREADY_EXIST);
        init_module(admin);
    }
    
    #[test(framework = @aptos_framework, admin = @my_addrx)]
    fun test_flow(framework: &signer, admin: &signer) {
        let addrx = signer::address_of(admin);
        aptos_framework::coin::create_coin_conversion_map(framework);
        init_module(admin);

        let balance = aptos_framework::coin::balance<FirstCoin>(addrx);
        assert!(balance == 100 * 100_000_000, 1);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        aptos_framework::coin::transfer<FirstCoin>(admin, alice_addrx, 10 * 100_000_000);
        let alice_balance = aptos_framework::coin::balance<FirstCoin>(alice_addrx);
        let admin_balance = aptos_framework::coin::balance<FirstCoin>(addrx);
        assert!(alice_balance == 10 * 100_000_000, 2);
        assert!(admin_balance == 90 * 100_000_000, 3);
    }
}