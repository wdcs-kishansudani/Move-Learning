module phantom_witness::registry {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::table::{Self, Table};
    use aptos_framework::account;

    /// Phantom witness type - used only for authorization
    struct RegistryWitness<phantom T> has copy, drop {}

    /// Only modules that can construct RegistryWitness<T> can register type T
    struct TypeRegistry has key {
        registered_types: Table<String, bool>,
    }

    /// Information about a registered type
    struct TypeInfo<phantom T> has key {
        name: String,
        creator: address,
        witness: RegistryWitness<T>,
    }

    /// Generic resource that requires witness for creation
    struct SecureResource<phantom T> has key {
        data: u64,
        authorized_by: RegistryWitness<T>,
    }

    /// Initialize the registry
    public fun init_registry(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        if (!exists<TypeRegistry>(admin_addr)) {
            move_to(admin, TypeRegistry {
                registered_types: table::new(),
            });
        }
    }

    /// Create a witness - only the module defining T can call this
    /// This is the key security mechanism
    public fun create_witness<T>(): RegistryWitness<T> {
        RegistryWitness<T> {}
    }

    /// Register a type with witness-based authorization
    public fun register_type<T>(
        creator: &signer,
        type_name: String,
        _witness: RegistryWitness<T>  // Witness proves authorization
    ) acquires TypeRegistry {
        let creator_addr = signer::address_of(creator);
        
        // Store type information
        move_to(creator, TypeInfo<T> {
            name: type_name,
            creator: creator_addr,
            witness: create_witness<T>(),
        });

        // Update global registry
        let registry = borrow_global_mut<TypeRegistry>(@phantom_witness);
        table::add(&mut registry.registered_types, type_name, true);
    }

    /// Create secure resource - requires witness
    public fun create_secure_resource<T>(
        account: &signer,
        data: u64,
        witness: RegistryWitness<T>
    ): SecureResource<T> {
        SecureResource<T> {
            data,
            authorized_by: witness,
        }
    }

    /// Access secure resource data
    public fun get_resource_data<T>(resource: &SecureResource<T>): u64 {
        resource.data
    }

    /// Update resource - requires witness again
    public fun update_resource<T>(
        resource: &mut SecureResource<T>,
        new_data: u64,
        _witness: RegistryWitness<T>  // Re-authorization required
    ) {
        resource.data = new_data;
    }

    /// Check if type is registered
    public fun is_type_registered(type_name: String): bool acquires TypeRegistry {
        let registry = borrow_global<TypeRegistry>(@phantom_witness);
        table::contains(&registry.registered_types, type_name)
    }

    /// Example usage module
    module phantom_witness::example_types {
        use phantom_witness::registry;
        use std::string;
        use std::signer;

        /// Custom type marker
        struct MyCustomType {}

        /// Another custom type
        struct AnotherType {}

        /// Initialize and register custom types
        public fun setup(creator: &signer) {
            // Only this module can create witness for MyCustomType
            let witness1 = create_witness<MyCustomType>();
            let witness2 = create_witness<AnotherType>();

            register_type<MyCustomType>(
                creator,
                string::utf8(b"MyCustomType"),
                witness1
            );

            register_type<AnotherType>(
                creator,
                string::utf8(b"AnotherType"),
                witness2
            );
        }

        /// Create resource with type safety
        public fun create_my_resource(
            account: &signer,
            data: u64
        ): SecureResource<MyCustomType> {
            let witness = create_witness<MyCustomType>();
            create_secure_resource(account, data, witness)
        }

        /// Update with authorization
        public fun update_my_resource(
            resource: &mut SecureResource<MyCustomType>,
            new_data: u64
        ) {
            let witness = create_witness<MyCustomType>();
            update_resource(resource, new_data, witness);
        }

        #[test(creator = @0x123, user = @0x456)]
        fun test_witness_pattern(creator: signer, user: signer) {
            init_registry(&creator);
            setup(&creator);

            // Create resource
            let resource = create_my_resource(&user, 42);
            assert!(get_resource_data(&resource) == 42, 1);

            // Update resource
            update_my_resource(&mut resource, 100);
            assert!(get_resource_data(&resource) == 100, 2);

            // Verify type registration
            assert!(is_type_registered(string::utf8(b"MyCustomType")), 3);

            // Clean up
            let SecureResource { data: _, authorized_by: _ } = resource;
        }
    }
}