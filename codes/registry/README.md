**Scenario:**
You’re building a **Cross-Module Resource Registry**. Think of it as an **on-chain plugin system**: different modules can “register” their custom resource types, and your registry manages them generically.

---

### 📝 Requirements

1. Define a `Registry` resource stored at a known address (say, `@my_addrx`).

2. The registry should allow **any module** to register its resource type `R<phantom T>` with a unique string name.

   - Example: `NFT<Art>` registers as `"art_nft"`.
   - `Vault<USDC>` registers as `"usdc_vault"`.

3. Store this mapping in a `Table<string, address>` (mapping name → account where that resource type lives).

4. Implement:

   - `register<T>(signer: &signer, name: string)` → Registers `Role<T>` or `Vault<T>` or any phantom resource.
   - `lookup(name: string): address` → Returns the owner address where that resource is published.
   - `exists<T>(addr: address): bool` → Checks if `addr` has resource `T`.

5. Enforce that:

   - Only the **owner of the resource** can register it.
   - Names must be **unique**.

6. (Bonus 🔥) Extend to support **type-safe dispatch**:

   - Example: Given a `name`, safely check whether the resource is of type `T`.
   - This forces you to mix **phantom types + runtime registry lookups**.
