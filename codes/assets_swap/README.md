**Scenario:**
You’re designing a **Meta-Escrow System** that works across **multiple modules + multiple asset types**, while enforcing **capability-guarded actions**.

---

### 📝 Requirements

1. Define a `Deal<phantom A, phantom B>` resource that represents a swap between two arbitrary asset types `A` and `B`.

   - Example: Alice escrows `Vault<USDC>` and Bob escrows `Vault<NFT<Art>>`.

2. Each deal must:

   - Track **initiator** and **counterparty** addresses.
   - Store **who deposited what**, without mixing types.
   - Prevent premature release unless both sides are satisfied.

3. Implement core functions:

   - `initiate<A, B>(alice: &signer, bob: address, amount_a: u64)`
   - `deposit_b<A, B>(bob: &signer, amount_b: u64)`
   - `cancel<A, B>(initiator: &signer)` → only possible if Bob hasn’t deposited yet.
   - `swap_and_release<A, B>()` → atomically transfers both assets.

4. Security constraints:

   - Must use **phantom type safety** so you can’t accidentally swap mismatched types.
   - Must use **capabilities** so only the system can move escrowed assets.
   - Prevent **double release** or **reentrancy-like bugs**.

5. (Bonus 🔥) Add **pluggable arbitration**:

   - Allow a third-party arbitrator module to decide the outcome of a deal.
   - Registry-based lookup (use the registry pattern from your last task).
