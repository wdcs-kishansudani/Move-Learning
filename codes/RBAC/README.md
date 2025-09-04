**Scenario:**
You’re building a **Role-Based Access Control (RBAC)** system using `phantom<T>` to encode _roles_ at the type level.

**Requirements:**

1. Define a `Role<phantom T>` resource that represents an access right tied to a specific type `T`.

   - Example: `Role<Admin>` vs `Role<Moderator>` vs `Role<User>`.

2. Implement:

   - `assign_role<T>(account: &signer)` → gives the account a `Role<phantom T>`.
   - `check_role<T>(account: address)` → verifies the account has `Role<phantom T>`.
   - `only_role<T>(account: &signer)` → aborts if the signer lacks that role.

3. Make roles **non-transferable**. Once assigned, the capability/resource is locked to that account.

4. (Bonus 🔥) Implement **hierarchical roles**:

   - `Admin` can perform any action a `Moderator` or `User` can.
   - Encode this in the type system if possible, or enforce with logic.

---

💡 Why this is god-tier?

- It forces you to use `phantom<T>` _not just for assets_, but for **type-level authority**.
- You’ll explore **capability patterns + generics**.
- It’s exactly the kind of **tricky design question**.
