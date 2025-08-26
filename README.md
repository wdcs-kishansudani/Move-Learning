# Aptos Move Level-Check Exercises
## Move hands on exercise to learn Aptos move language

#### 🌱 Beginner Level
- [X] HelloMove Module
- [X] Account Balance Query
- [X] Basic Counter Resource
- [X] Simple Transfer
#### ⚡ Intermediate Level
- [X] Vault Resource (COIN)
- [X] NFT Minting
- [X] Access Control
- [X] Composed Transaction (NFT + COIN)
#### 🚀 Advanced Level
- [ ] Resource Account Deployer
- [X] Secondary Store (FA + Store)
- [X] Nested Objects (NFT + Object)
- [ ] Module Upgrade with State Preservation
- [ ] Unit Tests

## 🌱 Beginner Level (Foundations)

### Prerequisites

* Aptos CLI installed (`aptos --version`).
* Aptos account initialized on **Devnet** (`aptos init`).
* Basic programming knowledge (structs, functions, variables).

### Exercises

---

### 1. **HelloMove Module**

**What to Do:**

* Write a `HelloMove` module that defines a resource storing a string (e.g., `"Hello, Move!"`).
* Add two functions:

  1. **set\_message**: update the stored string.
  2. **get\_message**: return the string.

**Required Output:**

* After publishing, calling `get_message` should return `"Hello, Move!"`.
* If you call `set_message("Welcome to Aptos")`, then `get_message` should now return `"Welcome to Aptos"`.

---

### 2. **Account Balance Query**

**What to Do:**

* Write a Move **script** that reads your APT balance.
* Execute the script with your account as the signer.

**Required Output:**

* Running the script should print/log your balance (example: `"Balance: 999999000000"`).
* The value should match what `aptos account balance` shows in CLI.

---

### 3. **Basic Counter Resource**

**What to Do:**

* Define a resource `Counter { value: u64 }`.
* Add functions:

  * `create_counter`: publish a counter starting at `0` under the signer’s account.
  * `increment`: increase by 1.
  * `decrement`: decrease by 1.

**Required Output:**

* Initially: counter value = `0`.
* After calling `increment` twice → counter value = `2`.
* After `decrement` once → counter value = `1`.

---

### 4. **First Coin**

**What to Do:**

* Define a custom coin type `MyCoin`.
* Initialize supply and register the coin for your account.
* Mint some coins into your account balance.

**Required Output:**

* Running CLI command:

  ```bash
  aptos account balance --account <your_address>
  ```

  should show non-zero `MyCoin` balance.

---

### 5. **Simple Transfer**

**What to Do:**

* Using the coin you created in Exercise 4, implement a `transfer` function.
* Send coins from your account to another account.

**Required Output:**

* Before transfer:

  * Alice = `100` MyCoin
  * Bob = `0` MyCoin
* After transfer of `40`:

  * Alice = `60`
  * Bob = `40`

---

👉 If you succeed here → you have **fundamentals of resources, module publishing, CLI interaction, and coin basics**.

---

## ⚡ Intermediate Level (Ownership, Events, Composability)

### Prerequisites

* Comfortable with Beginner exercises.
* Knowledge of Move’s `move_to`, `move_from`, `has key` resources.
* Familiarity with Aptos framework modules (`0x1::coin`, `0x1::event`, `0x1::object`).

### Exercises

---

### 1. **Vault Resource**

**What to Do:**

* Create a `Vault` resource per account.
* Functions:

  * `create_vault`: initialize vault with 0 coins.
  * `deposit`: transfer coins into the vault.
  * `withdraw`: transfer coins out of the vault.

**Required Output:**

* If Alice deposits `50` MyCoin, her vault shows balance `50`.
* Withdrawing `20` leaves vault with `30`.

---

### 2. **NFT Minting**

**What to Do:**

* Use `0x1::object` to create an `Object<Metadata>` representing an NFT.
* `Metadata` should include name, description.
* Mint NFT to your account.

**Required Output:**

* After mint, your account owns an NFT object with unique ID.
* Querying it should return the stored metadata (e.g., `"NFT: Dragon, Rare Fire Dragon"`).

---

### 3. **Event Emission**

**What to Do:**

* Modify your vault or coin module so that:

  * Every `deposit` emits a `DepositEvent { amount }`.
  * Every `withdraw` emits a `WithdrawEvent { amount }`.

**Required Output:**

* After 2 deposits and 1 withdrawal, CLI should show 3 events.
* Example:

  ```
  DepositEvent { amount: 100 }
  DepositEvent { amount: 50 }
  WithdrawEvent { amount: 30 }
  ```

---

### 4. **Access Control (Admin Role)**

**What to Do:**

* Create an `Admin` resource stored at the deployer’s account.
* Only admin can call `mint` for your coin.
* Add `transfer_admin` to hand over admin rights.

**Required Output:**

* If Bob (not admin) calls `mint`, transaction aborts.
* After Alice transfers admin role to Bob, Bob can mint successfully.

---

### 5. **Composed Transaction (Script)**

**What to Do:**

* Write a Move **script** that:

  * Calls your vault’s `deposit`.
  * Immediately mints an NFT as a reward.

**Required Output:**

* After running script:

  * Vault balance increases.
  * New NFT appears in account.
* If either action fails, transaction rolls back (atomicity).

---

👉 If you succeed here → you understand **ownership, events, access control, composability**.

---

## 🚀 Advanced Level (Resource Accounts, Secondary Stores, Upgrades)

### Prerequisites

* Comfortable with Intermediate exercises.
* Familiar with Aptos concepts: **resource accounts, secondary stores, object nesting**.
* Able to write tests with `aptos move test`.

### Exercises

---

### 1. **Resource Account Deployer**

**What to Do:**

* Create a resource account.
* Publish a module from that account.
* That module should mint NFTs.

**Required Output:**

* NFTs minted by the resource account, **not by your EOA**.
* Ownership shows as coming from resource account.

---

### 2. **Secondary Store**

**What to Do:**

* Allow each user to have **multiple vaults** (Vault#1, Vault#2).
* Implement using `create_secondary_store`.

**Required Output:**

* Alice creates 2 vaults:

  * Vault#1: balance 100
  * Vault#2: balance 50
* Deposits/withdrawals work independently.

---

### 3. **Nested Objects**

**What to Do:**

* Create a **Collection NFT** that owns other NFTs.
* For example: Collection “My Art Gallery” containing NFT#1, NFT#2.

**Required Output:**

* Querying collection should show it owns children NFTs.
* Transferring the collection transfers all children automatically.

---

### 4. **Module Upgrade with State Preservation**

**What to Do:**

* Deploy a module from a resource account.
* Store state (e.g., vault balances).
* Upgrade the module (republish) with new features, while balances remain intact.

**Required Output:**

* After upgrade, calling old balances still returns correct values.
* New functions (e.g., interest accrual) work.

---

### 5. **Unit Tests**

**What to Do:**

* Write tests with `aptos move test` for your vault/coin/NFT modules.
* Cover:

  * Successful deposit/withdraw.
  * Error case (withdraw > balance).
  * Only admin can mint.

**Required Output:**

* Test runner shows passing tests:

  ```
  PASS  [tests] test_deposit
  PASS  [tests] test_withdraw
  PASS  [tests] test_mint_by_admin
  FAIL  [tests] test_mint_by_non_admin (expected abort)
  ```

---

👉 If you succeed here → you are **advanced Aptos Move developer level**, ready to build production-grade dApps.

---

✅ This now gives you:

* Clear **what each exercise is**
* Clear **expected results/outputs** so you know when it’s correct
* A ladder from Beginner → Intermediate → Advanced
