/// IN THIS FILE I'M ONLY PUTTING TEST BECAUSE IT DESPLAY HOW CAN I MINT DUMMY COINS

module my_addrx::helper {

    #[test_only]
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    #[test(framework = @aptos_framework, alice = @0x123)]
    public fun test_with_funds(framework: &signer, alice: &signer) {
        // 1. Initialize and let framework store capabilities
        aptos_coin::ensure_initialized_with_apt_fa_metadata_for_test();

        // 2. Create account
        account::create_account_for_test(@0x123);

        // 3. Register alice for AptosCoin
        coin::register<AptosCoin>(alice);

        // 4. Use the simpler mint function (framework handles capabilities)
        aptos_coin::mint(framework, @0x123, 100_00000000);

        assert!(coin::balance<AptosCoin>(@0x123) == 100_00000000, 0);
    }

    #[test(framework = @aptos_framework, alice = @0x123)]
    public fun test_with_funds_method2(
        framework: &signer, alice: &signer
    ) {
        // 1. Initialize and capture the capabilities
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);

        // 2. Create account
        account::create_account_for_test(@0x123);

        // 3. Register alice for AptosCoin
        coin::register<AptosCoin>(alice);

        // 4. Mint coins using the mint capability
        let coins = coin::mint<AptosCoin>(100_00000000, &mint_cap);
        coin::deposit(@0x123, coins);

        // 5. Destroy the capabilities (required)
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        assert!(coin::balance<AptosCoin>(@0x123) == 100_00000000, 0);
    }
}

