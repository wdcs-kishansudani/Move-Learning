module my_addrx::RBAC {
    use std::signer;

    const E_INVALID_ROLE: u64 = 1;
    const E_NO_ROLE_ASSIGNED: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;

    struct Admin {}

    struct Moderator {}

    struct User {}

    struct Role<phantom T> has key {}

    fun init_module(admin: &signer) {
        move_to(admin, Role<Admin> {});
    }

    fun assign_role<T>(account: &signer, to: &signer) {
        let addrx = signer::address_of(account);
        assert!(exists<Role<Admin>>((addrx)), E_NOT_ADMIN);

        move_to(to, Role<T> {});

    }

    fun only_role<T>(account: &signer): bool {
        let addrx = signer::address_of(account);

        assert!(exists<Role<T>>(addrx), E_INVALID_ROLE);

        true
    }

    #[test(admin = @my_addrx, alice = @0x456, bob = @0x789)]
    fun test(admin: &signer, alice: &signer, bob: &signer) {
        init_module(admin);
        assign_role<Moderator>(admin, alice);
        assign_role<User>(admin, bob);

        assert!(only_role<Moderator>(alice), 1);
        assert!(only_role<User>(bob), 2);
    }
}

