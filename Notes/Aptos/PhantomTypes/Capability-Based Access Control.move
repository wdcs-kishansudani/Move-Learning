module phantom_capability::rbac {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::timestamp;

    /// Permission types as phantom parameters
    struct ReadPermission {}

    struct WritePermission {}

    struct AdminPermission {}

    struct ExecutePermission {}

    /// Capability token with phantom type for permission
    struct Capability<phantom Permission> has store, drop {
        granted_at: u64,
        expires_at: u64,
        granted_by: address
    }

    /// Resource with access control
    struct ProtectedResource<phantom Permission> has key {
        data: u64,
        metadata: vector<u8>,
        required_capability: Capability<Permission>
    }

    /// Admin controls for the system
    struct AdminControls has key {
        admins: vector<address>,
        global_settings: u64
    }

    /// Errors
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_CAPABILITY_EXPIRED: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;

    /// Initialize admin controls
    public fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        move_to(
            admin,
            AdminControls { admins: vector::singleton(admin_addr), global_settings: 0 }
        );
    }

    /// Grant capability to user
    public fun grant_capability<Permission>(
        admin: &signer, duration: u64
    ): Capability<Permission> acquires AdminControls {
        let admin_addr = signer::address_of(admin);

        // Verify admin status
        assert!(is_admin(admin_addr), E_NOT_ADMIN);

        let now = timestamp::now_seconds();
        Capability<Permission> {
            granted_at: now,
            expires_at: now + duration,
            granted_by: admin_addr
        }
    }

    /// Create protected resource
    public fun create_protected_resource<Permission>(
        creator: &signer,
        initial_data: u64,
        metadata: vector<u8>,
        capability: Capability<Permission>
    ) {
        assert!(is_capability_valid(&capability), E_CAPABILITY_EXPIRED);

        move_to(
            creator,
            ProtectedResource<Permission> {
                data: initial_data,
                metadata,
                required_capability: capability
            }
        );
    }

    /// Read from resource (requires ReadPermission or higher)
    public fun read_resource<Permission>(
        addr: address, _capability: &Capability<Permission>
    ): u64 acquires ProtectedResource {
        assert!(
            exists<ProtectedResource<Permission>>(addr),
            E_NOT_AUTHORIZED
        );
        assert!(is_capability_valid(_capability), E_CAPABILITY_EXPIRED);

        let resource = borrow_global<ProtectedResource<Permission>>(addr);
        resource.data
    }

    /// Write to resource (requires WritePermission or AdminPermission)
    public fun write_resource<Permission>(
        addr: address, new_data: u64, capability: &Capability<Permission>
    ) acquires ProtectedResource {
        assert!(
            exists<ProtectedResource<Permission>>(addr),
            E_NOT_AUTHORIZED
        );
        assert!(is_capability_valid(capability), E_CAPABILITY_EXPIRED);

        let resource = borrow_global_mut<ProtectedResource<Permission>>(addr);
        resource.data = new_data;
    }

    /// Execute admin function (requires AdminPermission)
    public fun admin_execute(
        admin: &signer, new_settings: u64, _capability: &Capability<AdminPermission>
    ) acquires AdminControls {
        assert!(is_capability_valid(_capability), E_CAPABILITY_EXPIRED);

        let admin_addr = signer::address_of(admin);
        let controls = borrow_global_mut<AdminControls>(admin_addr);
        controls.global_settings = new_settings;
    }

    /// Capability inheritance - Admin can do anything
    public fun admin_as_read_capability(
        admin_cap: &Capability<AdminPermission>
    ): Capability<ReadPermission> {
        assert!(is_capability_valid(admin_cap), E_CAPABILITY_EXPIRED);

        Capability<ReadPermission> {
            granted_at: admin_cap.granted_at,
            expires_at: admin_cap.expires_at,
            granted_by: admin_cap.granted_by
        }
    }

    public fun admin_as_write_capability(
        admin_cap: &Capability<AdminPermission>
    ): Capability<WritePermission> {
        assert!(is_capability_valid(admin_cap), E_CAPABILITY_EXPIRED);

        Capability<WritePermission> {
            granted_at: admin_cap.granted_at,
            expires_at: admin_cap.expires_at,
            granted_by: admin_cap.granted_by
        }
    }

    /// Utility functions
    fun is_capability_valid<Permission>(cap: &Capability<Permission>): bool {
        let now = timestamp::now_seconds();
        now <= cap.expires_at
    }

    fun is_admin(addr: address): bool acquires AdminControls {
        if (!exists<AdminControls>(@phantom_capability)) {
            return false
        };

        let controls = borrow_global<AdminControls>(@phantom_capability);
        vector::contains(&controls.admins, &addr)
    }

    /// Revoke capability (by creating an expired one)
    public fun revoke_capability<Permission>(): Capability<Permission> {
        Capability<Permission> {
            granted_at: 0,
            expires_at: 0, // Already expired
            granted_by: @0x0
        }
    }

    #[test_only]
    use aptos_framework::timestamp;

    #[test(admin = @0x123, user = @0x456)]
    fun test_capability_system(admin: signer, user: signer) acquires AdminControls, ProtectedResource {
        timestamp::set_time_has_started_for_testing(&admin);
        initialize(&admin);

        // Grant read capability
        let read_cap = grant_capability<ReadPermission>(&admin, 3600);

        // Grant admin capability
        let admin_cap = grant_capability<AdminPermission>(&admin, 7200);

        // Create protected resource
        create_protected_resource(&user, 42, b"test metadata", read_cap);

        // Test reading with read permission
        let new_read_cap = grant_capability<ReadPermission>(&admin, 3600);
        let data = read_resource<ReadPermission>(
            signer::address_of(&user), &new_read_cap
        );
        assert!(data == 42, 1);

        // Test admin capability inheritance
        let admin_as_read = admin_as_read_capability(&admin_cap);
        let data2 =
            read_resource<ReadPermission>(signer::address_of(&user), &admin_as_read);
        assert!(data2 == 42, 2);

        // Test writing with admin capability
        let admin_as_write = admin_as_write_capability(&admin_cap);
        write_resource<WritePermission>(
            signer::address_of(&user),
            100,
            &admin_as_write
        );
    }
}

