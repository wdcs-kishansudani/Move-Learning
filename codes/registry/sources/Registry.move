module my_addrx::Registry {
    use std::signer;
    use std::string::{Self, String};
    use std::table::{Self, Table};
    use std::object::{Self, Object};
    use aptos_std::type_info::{Self, TypeInfo};

    const EALREADY_REGISTERED: u64 = 1;
    const ENOT_REGISTERED: u64 = 2;
    const EMODULE_NOT_INITIALIZED: u64 = 3;
    const E_RESOURCE_NOT_FOUND: u64 = 4;
    const E_NOT_AUTHORIZED: u64 = 5;
    const E_NAME_ALREADY_EXISTS: u64 = 6;

    const SEED: vector<u8> = b"THIS IS EPIC REGISTRY SEED!!";

    struct Registry has key {
        name_to_address: Table<String, address>,
        type_to_name: Table<TypeInfo, String>
    }

    struct ResourceRef<phantom T> has key {
        owner: address,
        typer_info: TypeInfo
    }

    fun init_module(admin: &signer) {
        move_to(
            admin,
            Registry {
                name_to_address: table::new<String, address>(),
                type_to_name: table::new<TypeInfo, String>()
            }
        );
    }

    public fun register<T>(user: &signer, name: vector<u8>) acquires Registry {
        let addr = signer::address_of(user);
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        // Checking if user owns the resource from another module
        assert!(exists<T>(addr), E_NOT_AUTHORIZED);

        let registry = borrow_global_mut<Registry>(admin_addr);

        let name = string::utf8(name);

        assert!(
            !registry.name_to_address.contains(name),
            E_NAME_ALREADY_EXISTS
        );
        assert!(
            !exists<ResourceRef<T>>(addr),
            EALREADY_REGISTERED
        );

        let typer_info = type_info::type_of<T>();

        registry.name_to_address.add(name, addr);
        registry.type_to_name.add(typer_info, name);

        move_to(user, ResourceRef<T> { owner: addr, typer_info });

    }

    public fun lookup<T>(name: String): address acquires Registry {
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        let registry = borrow_global<Registry>(admin_addr);
        assert!(registry.name_to_address.contains(name), ENOT_REGISTERED);
        *registry.name_to_address.borrow(name)
    }

    public fun is_registered<T>(addr: address): bool {
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        exists<ResourceRef<T>>(addr)
    }

    public fun is_type<T>(name: String): bool acquires Registry, ResourceRef {
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        let registry = borrow_global_mut<Registry>(admin_addr);
        assert!(
            registry.name_to_address.contains(name),
            ENOT_REGISTERED
        );

        let expected_type = type_info::type_of<T>();
        let resource_holder = *registry.name_to_address.borrow(name);

        assert!(
            exists<ResourceRef<T>>(resource_holder),
            E_RESOURCE_NOT_FOUND
        );

        borrow_global<ResourceRef<T>>(resource_holder).typer_info == expected_type

    }

    public fun get_name_for_type<T>(): String acquires Registry {
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        let registry = borrow_global_mut<Registry>(admin_addr);
        let typer_info = type_info::type_of<T>();
        assert!(
            registry.type_to_name.contains(typer_info),
            ENOT_REGISTERED
        );

        *registry.type_to_name.borrow(typer_info)
    }

    public fun unregister<T>(user: &signer) acquires Registry, ResourceRef {
        let addr = signer::address_of(user);
        let admin_addr = @my_addrx;

        assert!(exists<Registry>(admin_addr), EMODULE_NOT_INITIALIZED);

        let registry = borrow_global_mut<Registry>(admin_addr);

        assert!(
            exists<ResourceRef<T>>(addr),
            E_RESOURCE_NOT_FOUND
        );

        let ResourceRef { owner: _, typer_info } = move_from<ResourceRef<T>>(addr);
        let name = registry.type_to_name.borrow(typer_info);

        registry.name_to_address.remove(*name);
        registry.type_to_name.remove(typer_info);

    }

    #[test_only]
    struct TestNFT<phantom T> has key {
        id: u64
    }

    #[test_only]
    struct TestVault<phantom T> has key, store {
        balance: u64
    }

    #[test_only]
    struct ArtType has drop {}

    #[test_only]
    struct USDCType has drop {}

    #[test(deployer = @my_addrx, alice = @0x123, bob = @0x456)]
    public fun test_registry_functionality(
        deployer: &signer, alice: &signer, bob: &signer
    ) acquires Registry, ResourceRef {
        init_module(deployer);

        let alice_addr = signer::address_of(alice);
        let bob_addr = signer::address_of(bob);

        let nft = TestNFT<ArtType> { id: 1 };
        move_to(alice, nft);
        register<TestNFT<ArtType>>(alice, b"art_nft");

        let vault = TestVault<USDCType> { balance: 1000 };
        move_to(bob, vault);
        register<TestVault<USDCType>>(bob, b"usdc_vault");

        assert!(lookup(string::utf8(b"art_nft")) == alice_addr, 1);
        assert!(lookup(string::utf8(b"usdc_vault")) == bob_addr, 2);

        assert!(exists<TestNFT<ArtType>>(alice_addr), 3);
        assert!(exists<TestVault<USDCType>>(bob_addr), 4);
        assert!(!exists<TestVault<USDCType>>(alice_addr), 5);

        assert!(
            is_type<TestNFT<ArtType>>(string::utf8(b"art_nft")),
            6
        );
        assert!(
            !is_type<TestVault<USDCType>>(string::utf8(b"art_nft")),
            7
        );

        assert!(
            get_name_for_type<TestNFT<ArtType>>() == string::utf8(b"art_nft"),
            8
        );

        unregister<TestNFT<ArtType>>(alice);
    }

    #[test(deployer = @my_addrx, alice = @0x123)]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED)]
    public fun test_unauthorized_registration(
        deployer: &signer, alice: &signer
    ) acquires Registry {
        init_module(deployer);

        register<TestNFT<ArtType>>(alice, b"unauthorized_nft");
    }

    #[test(deployer = @my_addrx, alice = @0x123)]
    #[expected_failure(abort_code = E_NAME_ALREADY_EXISTS)]
    public fun test_duplicate_name_registration(
        deployer: &signer, alice: &signer
    ) acquires Registry, ResourceRef {
        init_module(deployer);

        let nft1 = TestNFT<ArtType> { id: 1 };
        let nft2 = TestNFT<USDCType> { id: 2 };
        move_to(alice, nft1);
        move_to(alice, nft2);

        register<TestNFT<ArtType>>(alice, b"same_name");
        register<TestNFT<USDCType>>(alice, b"same_name");
    }
}

