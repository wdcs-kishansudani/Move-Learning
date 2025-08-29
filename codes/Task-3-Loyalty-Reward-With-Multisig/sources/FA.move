module my_addrx::FA {
    use std::signer;
    use std::string;
    use std::vector;
    use std::option;
    use std::event;
    use std::simple_map::{Self, SimpleMap};
    use aptos_framework::timestamp;
    use aptos_framework::object::{Self, Object, DeleteRef, TransferRef as Trf};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::{Self, MintRef, BurnRef, TransferRef, Metadata};

    const SEED: vector<u8> = b"THIS IS EPIC SEED!!";
    const VAULT_SEED: vector<u8> = b"THIS IS EPIC VAULT SEED!!";
    const VAULT_STORE_SEED: vector<u8> = b"THIS IS EPIC VAULT STORE SEED!!";

    /// Error codes
    /// 0: Already initialized
    const EALREADY_INITIALIED: u64 = 0;
    /// 1: Module not initialized
    const ENOT_INITIALIZED: u64 = 1;
    /// 2: Not owner
    const ENOT_OWNER: u64 = 2;
    /// 3: Invalid amount
    const EINVALID_AMOUNT: u64 = 3;
    /// 4: Invalid expiry
    const EINVALID_EXPIERY: u64 = 4;
    /// 5: User not found
    const EUSER_NOT_FOUND: u64 = 5;

    /// System will store the token store address and token metadata with some refs
    struct System has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>,
        vault_addr: address
    }

    /// each mint has seprate object with amount and expiry
    struct TokenObject has key {
        amount: u64,
        expiry: u64,
        delete_ref: DeleteRef
    }

    /// token store will hold all the users object addresses,
    /// which contains the TokenObject with balance
    /// it will not directly transfer to user
    struct TokenStore has key {
        token_object: SimpleMap<address, vector<address>>,
        vault_transfer_ref: Trf
    }

    #[event]
    struct TokenMinted has drop, store {
        to: address,
        amount: u64
    }

    #[event]
    struct TokenClaimed has drop, store {
        from: address,
        amount: u64
    }

    #[event]
    struct TokenTransfered has drop, store {
        from: address,
        to: address,
        amount: u64
    }

    /// Checks if the signer is the owner
    fun assert_is_owner(addrx: address) {
        assert!(addrx == @my_addrx, ENOT_OWNER);
    }

    /// Initializes the module
    fun init_module(admin: &signer) {
        let addrx = signer::address_of(admin);
        assert!(!exists<System>(addrx), EALREADY_INITIALIED);

        let constructor_ref = object::create_named_object(admin, SEED);

        // create fungible token
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(b"EPIC"),
            string::utf8(b"EPIC"),
            8,
            string::utf8(b""),
            string::utf8(b"")
        );

        let metadata = object::object_from_constructor_ref(&constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(&constructor_ref);

        let vault_store_object = object::create_named_object(admin, VAULT_STORE_SEED);

        let vault_transfer_ref = object::generate_transfer_ref(&vault_store_object);
        let store = TokenStore { token_object: simple_map::create(), vault_transfer_ref };

        let vault_store_signer = object::generate_signer(&vault_store_object);
        let system = System {
            mint_ref,
            burn_ref,
            transfer_ref,
            metadata,
            vault_addr: signer::address_of(&vault_store_signer)
        };

        move_to(admin, system);

        move_to(&vault_store_signer, store);
    }

    /// Mints tokens
    /// Create new object with amount and expiry
    /// generate a primary store for that object
    /// mint & deposit token to object
    /// update users object addresses, this object will reflect as user balance
    fun mint(user: address, amount: u64, expiry: u64) acquires System, TokenStore {
        let sys = borrow_global<System>(@my_addrx);

        // create new object, object signer and object address
        let constructor_ref = object::create_object(sys.vault_addr);
        let delete_ref = object::generate_delete_ref(&constructor_ref);
        let token_obj = TokenObject { amount, expiry, delete_ref };
        let object_address = object::address_from_constructor_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);

        move_to(&object_signer, token_obj);

        // update users object addresses
        let store = borrow_global_mut<TokenStore>(sys.vault_addr);

        if (!store.token_object.contains_key(&user)) {
            store.token_object.add(user, vector::empty());
        };

        let user_obj_store = store.token_object.borrow_mut(&user);

        user_obj_store.push_back(object_address);

        fungible_asset::create_store(&constructor_ref, sys.metadata);
        let obj = object::object_from_constructor_ref<TokenObject>(&constructor_ref);
        let fa = fungible_asset::mint(&sys.mint_ref, amount);
        fungible_asset::deposit(obj, fa);

        event::emit(TokenMinted { to: user, amount });
    }

    /// Spends tokens
    /// This will burn the tokens and assume it is as spent
    fun spend(obj: Object<TokenObject>, amount: u64) acquires System {
        let sys = borrow_global<System>(@my_addrx);
        fungible_asset::burn_from(&sys.burn_ref, obj, amount);
    }

    /// Claims tokens
    /// User will spend the balance from object which are inside object store
    /// if balance is expire that balance will not count and continue with next object
    /// If user has less minted amount than amount he wants to claim, this will not thrown an error and claims what user has
    fun claim(user: address, amount: u64) acquires System, TokenObject, TokenStore {
        let sys = borrow_global<System>(@my_addrx);

        let store = borrow_global_mut<TokenStore>(sys.vault_addr);

        assert!(store.token_object.contains_key(&user), EUSER_NOT_FOUND);

        let user_amount_objs = store.token_object.borrow_mut(&user);

        let counter = 0;
        let claimble = amount;
        let len = user_amount_objs.length();
        let total_amount = 0;

        while (counter < len && claimble > 0) {
            let object_address = user_amount_objs.borrow_mut(counter);
            let obj = object::address_to_object(*object_address);

            if (check_object_expiery(*object_address)) {
                destroy_obj(obj, object_address);
                user_amount_objs.remove(counter);
            } else {
                let balance = fungible_asset::balance(obj);

                let send_amount = if (claimble >= balance) {
                    balance
                } else {
                    claimble
                };

                spend(obj, send_amount);

                if (balance <= claimble) {
                    destroy_obj(obj, object_address);
                    user_amount_objs.remove(counter);
                };

                total_amount += send_amount;
                claimble -= send_amount;
            };
            counter += 1;
        };

        event::emit(TokenClaimed { from: user, amount: total_amount });
    }

    /// Transfers tokens
    /// Transfer tokens from one user to admin
    /// it will just deref from user to admin
    /// in this it is transfering entire address, so if one obj has balance 100 and admin wants to transfer 10 coin
    /// it will transfer all 100
    fun transfer(user_from: address, amount: u64) acquires System, TokenStore, TokenObject {
        let sys = borrow_global<System>(@my_addrx);

        let store = borrow_global_mut<TokenStore>(sys.vault_addr);

        assert!(store.token_object.contains_key(&user_from), EUSER_NOT_FOUND);

        if (!store.token_object.contains_key(&@my_addrx)) {
            store.token_object.add(@my_addrx, vector::empty());
        };

        let counter = 0;
        let claimble = amount;
        let user_amount_objs = store.token_object.borrow_mut(&user_from);

        let len = user_amount_objs.length();
        let store_addr = vector::empty();
        let total_amount = 0;

        while (counter < len && claimble > 0) {
            let object_address = user_amount_objs.borrow_mut(counter);
            let obj = object::address_to_object(*object_address);

            if (check_object_expiery(*object_address)) {
                destroy_obj(obj, object_address);
                user_amount_objs.remove(counter);
            } else {
                let balance = fungible_asset::balance(obj);

                let send_amount = if (claimble >= balance) {
                    balance
                } else {
                    claimble
                };

                let addr = user_amount_objs.remove(counter);

                store_addr.push_back(addr);

                total_amount += send_amount;
                claimble -= send_amount;
            };
            counter += 1;
        };

        store_addr.for_each(|addr| {
            store.token_object.borrow_mut(&@my_addrx).push_back(addr);
        });

        event::emit(
            TokenTransfered { from: user_from, to: @my_addrx, amount: total_amount }
        );
    }

    /// Destroys the object
    /// Burn all the balance which object has and delete the object
    fun destroy_obj(obj: Object<TokenObject>, obj_addr: &address) acquires System, TokenObject {
        let sys = borrow_global<System>(@my_addrx);
        fungible_asset::burn_from(&sys.burn_ref, obj, fungible_asset::balance(obj));

        let TokenObject { amount: _amount, expiry: _expiry, delete_ref } =
            move_from<TokenObject>(*obj_addr);

        object::delete(delete_ref);
    }

    // Checks if the token is expired
    #[view]
    fun check_object_expiery(obj_addr: address): bool acquires TokenObject {
        let token_obj = borrow_global<TokenObject>(obj_addr);
        if (token_obj.expiry > timestamp::now_seconds()) { false }
        else { true }
    }

    /// Mints tokens
    public entry fun mint_to(
        admin: &signer,
        to: address,
        amount: u64,
        expiery: u64
    ) acquires System, TokenStore {
        assert_is_owner(signer::address_of(admin));
        assert!(amount > 0, EINVALID_AMOUNT);
        assert!(expiery > timestamp::now_seconds(), EINVALID_EXPIERY);
        mint(to, amount, expiery);
    }

    /// Claims tokens which has minted from admin
    public entry fun claim_amount(user: &signer, amount: u64) acquires System, TokenStore, TokenObject {
        assert!(amount > 0, EINVALID_AMOUNT);
        claim(signer::address_of(user), amount);
    }

    /// Burn existing tokens from user
    public entry fun burn_from_user(
        admin: &signer, from: address, amount: u64
    ) acquires System, TokenStore, TokenObject {
        assert_is_owner(signer::address_of(admin));
        assert!(amount > 0, EINVALID_AMOUNT);
        claim(from, amount);
    }

    /// transfer the tokens from user, which is minted from him
    public entry fun transfer_from_user(
        admin: &signer, from: address, amount: u64
    ) acquires System, TokenStore, TokenObject {
        assert_is_owner(signer::address_of(admin));
        assert!(amount > 0, EINVALID_AMOUNT);
        transfer(from, amount);
    }

    #[view]
    public fun balance_of(account: address): u64 acquires System, TokenStore {
        let sys = borrow_global<System>(@my_addrx);

        let store = borrow_global_mut<TokenStore>(sys.vault_addr);

        assert!(store.token_object.contains_key(&account), EUSER_NOT_FOUND);

        let user_amount_objs = store.token_object.borrow_mut(&account);

        let counter = 0;
        let len = user_amount_objs.length();
        let total = 0;

        while (counter < len) {
            let object_address = user_amount_objs.borrow_mut(counter);
            let obj = object::address_to_object<TokenObject>(*object_address);

            let bal = fungible_asset::balance(obj);

            total += bal;

            counter += 1;
        };

        total
    }

    #[test(aptos_framework = @aptos_framework, admin = @my_addrx)]
    public fun test_flow(
        aptos_framework: &signer, admin: &signer
    ) acquires System, TokenStore, TokenObject {
        init_module(admin);
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        mint_to(
            admin,
            alice_addrx,
            100,
            timestamp::now_seconds() + 100
        );
        let alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 100, 1);

        claim_amount(&alice, 10);
        alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 90, 2);

        timestamp::update_global_time_for_test_secs(1000000000);

        claim_amount(&alice, 10);
        alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 0, 3);
    }

    #[test(aptos_framework = @aptos_framework, admin = @my_addrx)]
    public fun burn_amount(
        aptos_framework: &signer, admin: &signer
    ) acquires System, TokenStore, TokenObject {
        init_module(admin);
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        mint_to(
            admin,
            alice_addrx,
            100,
            timestamp::now_seconds() + 100
        );
        let alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 100, 1);

        burn_from_user(admin, alice_addrx, 100);
        alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 0, 2);
    }

    #[test(aptos_framework = @aptos_framework, admin = @my_addrx)]
    public fun transfer_amount(
        aptos_framework: &signer, admin: &signer
    ) acquires System, TokenStore, TokenObject {
        init_module(admin);
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let alice = aptos_framework::account::create_account_for_test(@0x2);
        let alice_addrx = signer::address_of(&alice);

        mint_to(
            admin,
            alice_addrx,
            100,
            timestamp::now_seconds() + 100
        );
        let alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 100, 1);

        transfer_from_user(admin, alice_addrx, 10);
        alice_balance = balance_of(alice_addrx);
        assert!(alice_balance == 0, 2);

        let admin_balance = balance_of(signer::address_of(admin));

        assert!(admin_balance == 100, 3);
    }
}

