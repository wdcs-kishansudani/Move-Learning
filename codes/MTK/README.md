**Scenario:**
You are designing a **Permissioned Token Minting System**.

**Requirements:**

1. Define a `MintCap<phantom T>` capability that allows minting of a fungible asset `T`.

   - Example: `MintCap<USD>` vs `MintCap<EUR>`.

2. Only **whitelisted accounts** (like a central bank, or an issuer) can hold a `MintCap<T>`.

3. Implement:

   - `create_token<T>(admin: &signer)` → Deploys a new fungible asset type `T` and gives the admin its `MintCap<T>`.
   - `assign_mint_cap<T>(admin: &signer, to: &signer)` → Admin can delegate a `MintCap<T>` to another issuer.
   - `mint<T>(issuer: &signer, amount: u64)` → Requires issuer to hold `MintCap<T>`.

4. Make `MintCap<T>` **non-transferable** except via `assign_mint_cap`.

5. (Bonus 🔥) Add **revocation**: admin can revoke a `MintCap<T>` from any issuer.

---

### 📌 Constraints

- Use **phantom<T>** so different tokens’ mint caps don’t mix.
- Capabilities must be **account-bound** (issuer cannot move them around arbitrarily).
- Prevent **replay attacks** (e.g., double-spending or reusing revoked caps).
