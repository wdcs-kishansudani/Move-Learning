module phantom_currency::safe_coin {
    use std::signer;
    use aptos_framework::account;

    /// Phantom type for USD currency
    struct USD {}

    /// Phantom type for EUR currency
    struct EUR {}

    /// Phantom type for BTC currency
    struct BTC {}

    /// Generic coin with phantom type parameter
    /// Currency type provides compile-time type safety
    struct Coin<phantom CurrencyType> has store, drop {
        value: u64
    }

    /// Mint capability tied to specific currency
    struct MintCap<phantom CurrencyType> has key {}

    /// Treasury for managing currency supply
    struct Treasury<phantom CurrencyType> has key {
        total_supply: u64,
        mint_cap: MintCap<CurrencyType>
    }

    /// Initialize a new currency type
    public fun initialize_currency<CurrencyType>(admin: &signer) {
        let admin_addr = signer::address_of(admin);

        move_to(
            admin,
            Treasury<CurrencyType> {
                total_supply: 0,
                mint_cap: MintCap<CurrencyType> {}
            }
        );
    }

    /// Mint coins of specific currency type
    public fun mint<CurrencyType>(admin: &signer, amount: u64): Coin<CurrencyType> acquires Treasury {
        let admin_addr = signer::address_of(admin);

        // Verify admin has mint capability
        assert!(
            exists<Treasury<CurrencyType>>(admin_addr),
            1
        );

        let treasury = borrow_global_mut<Treasury<CurrencyType>>(admin_addr);
        treasury.total_supply = treasury.total_supply + amount;

        Coin<CurrencyType> { value: amount }
    }

    /// Get coin value (works for any currency type)
    public fun value<CurrencyType>(coin: &Coin<CurrencyType>): u64 {
        coin.value
    }

    /// Merge two coins of the same currency type
    public fun merge<CurrencyType>(
        dst: &mut Coin<CurrencyType>, source: Coin<CurrencyType>
    ) {
        let Coin { value } = source;
        dst.value = dst.value + value;
    }

    /// Split coin into two parts
    public fun split<CurrencyType>(
        coin: &mut Coin<CurrencyType>, amount: u64
    ): Coin<CurrencyType> {
        assert!(coin.value >= amount, 2);
        coin.value = coin.value - amount;

        Coin<CurrencyType> { value: amount }
    }

    /// Burn coins and update supply
    public fun burn<CurrencyType>(
        admin: &signer, coin: Coin<CurrencyType>
    ) acquires Treasury {
        let admin_addr = signer::address_of(admin);
        let treasury = borrow_global_mut<Treasury<CurrencyType>>(admin_addr);

        let Coin { value } = coin;
        treasury.total_supply = treasury.total_supply - value;
    }

    /// Exchange function (compile-time type safety!)
    /// This will only compile if From and To are different types
    public fun exchange<From, To>(_from_coin: Coin<From>, to_amount: u64): Coin<To> {
        // In real implementation, you'd have exchange rate logic
        // This demonstrates the type safety
        Coin<To> { value: to_amount }
    }

    /// Specialized functions for specific currencies
    public fun mint_usd(admin: &signer, amount: u64): Coin<USD> acquires Treasury {
        mint<USD>(admin, amount)
    }

    public fun mint_eur(admin: &signer, amount: u64): Coin<EUR> acquires Treasury {
        mint<EUR>(admin, amount)
    }

    /// Type-safe exchange functions
    public fun usd_to_eur(usd_coin: Coin<USD>, eur_amount: u64): Coin<EUR> {
        exchange<USD, EUR>(usd_coin, eur_amount)
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize_currency<USD>(admin);
        initialize_currency<EUR>(admin);
        initialize_currency<BTC>(admin);
    }

    #[test(admin = @0x123)]
    fun test_phantom_type_safety(admin: signer) acquires Treasury {
        init_for_test(&admin);

        let usd_coin = mint_usd(&admin, 100);
        let eur_coin = mint_eur(&admin, 80);

        // This works - same currency types
        let more_usd = split(&mut usd_coin, 50);
        merge(&mut usd_coin, more_usd);

        // This would NOT compile - different currency types
        // merge(&mut usd_coin, eur_coin);  // ERROR!

        assert!(value(&usd_coin) == 100, 1);
        assert!(value(&eur_coin) == 80, 2);

        // Clean up
        burn(&admin, usd_coin);
        burn(&admin, eur_coin);
    }
}

