module my_addrx::Vault {
    use std::signer;
    use std::event;
    use my_addrx::FirstCoin;
    use aptos_framework::coin;
    use aptos_framework::account::{Self, SignerCapability};

    const EVAULT_ALREADY_EXIST: u64 = 0;
    const EVAULT_DOENT_EXIST: u64 = 1;
    const EINSUFFICIENT_VAULT_BALANCE: u64 = 2;

    const VAULT_SEED: vector<u8> = b"THIS IS YOUR PERSONAL VAULT";

    struct Vault has key {
        amount: u64
    }

    struct VaultAddress has key {
        vault: address,
        cap: SignerCapability
    }

    #[event]
    struct CoinDeposited has store, drop {
        amount: u64
    }

    #[event]
    struct CoinWithdrawn has store, drop {
        amount: u64
    }

    public entry fun register(account: &signer) {
        let addrx = signer::address_of(account);
        assert!(!exists<VaultAddress>(addrx), EVAULT_ALREADY_EXIST);

        let (vault_signer, vault_cap) = account::create_resource_account(account, VAULT_SEED);

        move_to(&vault_signer, Vault {
            amount: 0
        });

        move_to(account, VaultAddress {
            vault: signer::address_of(&vault_signer),
            cap: vault_cap
        });
    }

    public entry fun deposit(account: &signer, amount: u64) acquires Vault, VaultAddress {
        let addrx = signer::address_of(account);
        assert!(exists<VaultAddress>(addrx), EVAULT_DOENT_EXIST);

        let vault_addr = &borrow_global<VaultAddress>(addrx).vault;

        coin::transfer<FirstCoin::FirstCoin>(account, *vault_addr, amount);

        let vault: &mut Vault = borrow_global_mut(*vault_addr);
        vault.amount += amount;

        event::emit(CoinDeposited {
            amount
        });
    }

    public entry fun withdraw(account: &signer, amount: u64) acquires Vault, VaultAddress {
        let addrx = signer::address_of(account);
        assert!(exists<VaultAddress>(addrx), EVAULT_DOENT_EXIST);

        let vault_addr = borrow_global<VaultAddress>(addrx);
        let vault: &mut Vault = borrow_global_mut(vault_addr.vault);

        assert!(vault.amount >= amount, EINSUFFICIENT_VAULT_BALANCE);

        let vault_signer = account::create_signer_with_capability(&vault_addr.cap);
        vault.amount -= amount;
        coin::transfer<FirstCoin::FirstCoin>(&vault_signer, addrx, amount);
        
        event::emit(CoinWithdrawn {
            amount
        });
    }

    #[view]
    public fun get_vault_balance(account: address): u64 acquires Vault, VaultAddress {
        if(!exists<VaultAddress>(account)) {
            0
        }else {
            let vault_addr = borrow_global<VaultAddress>(account);
            let vault: &Vault = borrow_global(vault_addr.vault);

            vault.amount
        }
    }

    #[test(framework =  @aptos_framework, admin = @my_addrx)]
    public fun test_flow(framework: &signer, admin: &signer) acquires Vault, VaultAddress {
        let addrx = signer::address_of(admin);
        aptos_framework::coin::create_coin_conversion_map(framework);
        FirstCoin::deploy(admin);

        let balance = aptos_framework::coin::balance<FirstCoin::FirstCoin>(addrx);
        assert!(balance == 100 * 100_000_000, 1);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        aptos_framework::coin::transfer<FirstCoin::FirstCoin>(admin, alice_addrx, 50 * 100_000_000);
        let alice_balance = aptos_framework::coin::balance<FirstCoin::FirstCoin>(alice_addrx);
        let admin_balance = aptos_framework::coin::balance<FirstCoin::FirstCoin>(addrx);
        assert!(alice_balance == 50 * 100_000_000, 2);
        assert!(admin_balance == 50 * 100_000_000, 3);

        register(&alice);

        assert!(get_vault_balance(alice_addrx) == 0, 4);
        deposit(&alice, 50);
        assert!(get_vault_balance(alice_addrx) == 50, 5);

        withdraw(&alice, 50);
        assert!(get_vault_balance(alice_addrx) == 0, 6);
    }
}