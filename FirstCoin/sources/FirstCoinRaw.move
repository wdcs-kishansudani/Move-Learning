module my_addrx::FirstCoinRaw {
    use std::signer;
    use std::string;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    const ENO_CAP: u64 = 0;

    struct FirstCoinRaw {}

    struct Capabilities has key {
        mint_cap: MintCapability<FirstCoinRaw>,
        burn_cap: BurnCapability<FirstCoinRaw>,
    }

    fun init_module(admin: &signer) {
        let  (burn_cap, freeze_cap, mint_cap) = coin::initialize<FirstCoinRaw>(
            admin,
            string::utf8(b"FirstRawCoin"),
            string::utf8(b"FRC"),
            8,
            false
        );

        coin::destroy_freeze_cap(freeze_cap);

        move_to(admin, Capabilities {
            mint_cap,
            burn_cap
        });
    }

    public entry fun mint(admin: &signer, to: address, amount: u64) acquires Capabilities {
        let addrx = signer::address_of(admin);
        assert!(exists<Capabilities>(addrx), ENO_CAP);

        let cap = borrow_global<Capabilities>(addrx);
        let coin_minted = coin::mint<FirstCoinRaw>(amount, &cap.mint_cap);
        coin::deposit(to, coin_minted);
    }

    public entry fun burn(admin: &signer, from: address, amount: u64) acquires Capabilities {
        let addrx = signer::address_of(admin);
        assert!(exists<Capabilities>(addrx), ENO_CAP);

        let cap = borrow_global<Capabilities>(addrx);
        coin::burn_from<FirstCoinRaw>(from, amount, &cap.burn_cap);
    }

    public entry fun register_coin(account: &signer) {
        coin::register<FirstCoinRaw>(account);
    }

    #[test(framework = @aptos_framework,admin = @my_addrx)]
    fun test_flow(framework: &signer, admin: &signer) acquires Capabilities {
        let addrx = signer::address_of(admin);
        aptos_framework::coin::create_coin_conversion_map(framework);
        init_module(admin);

        let balance = aptos_framework::coin::balance<FirstCoinRaw>(addrx);
        assert!(balance == 0, 1);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        mint(admin, addrx, 100 * 100_000_000);
        let admin_balance = aptos_framework::coin::balance<FirstCoinRaw>(addrx);
        assert!(admin_balance == 100 * 100_000_000, 1);
        
        aptos_framework::coin::transfer<FirstCoinRaw>(admin, alice_addrx, 10 * 100_000_000);
        let alice_balance = aptos_framework::coin::balance<FirstCoinRaw>(alice_addrx);
        let admin_balance = aptos_framework::coin::balance<FirstCoinRaw>(addrx);
        assert!(alice_balance == 10 * 100_000_000, 2);
        assert!(admin_balance == 90 * 100_000_000, 3);

        mint(admin, alice_addrx, 10 * 100_000_000);
        let alice_balance = aptos_framework::coin::balance<FirstCoinRaw>(alice_addrx);
        assert!(alice_balance == 20 * 100_000_000, 4);

        burn(admin, alice_addrx, 10 * 100_000_000);
        let alice_balance = aptos_framework::coin::balance<FirstCoinRaw>(alice_addrx);
        assert!(alice_balance == 10 * 100_000_000, 5);
    }
}