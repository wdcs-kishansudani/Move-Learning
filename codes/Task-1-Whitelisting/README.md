# Address Whitelisting and Fund Deposit

## Overview:

- This contract implements an address whitelisting mechanism, allowing only approved users to deposit funds. The contract admin can manage the whitelist, including adding and removing addresses individually or in bulk.

### Features & Requirements:

#### Admin Controls:

- The contract should have an admin role with exclusive permissions to manage the whitelist.
- The admin can add or remove a single address from the whitelist.
- The admin can perform bulk addition and removal of addresses.

#### Whitelisting Mechanism:

- Only whitelisted addresses are allowed to deposit funds into the contract.
- Non-whitelisted addresses should be restricted from depositing funds.

#### Fund Deposit & Storage:

- A dedicated resource account should be created at the time of contract initialization.
- All client deposits should be stored in this resource account.
- To store whitelisting user records use different resource accounts.

#### Security & Access Control:

- The contract should ensure proper access control mechanisms, restricting critical functions to the admin.
- Deposits should only be accepted from whitelisted addresses.

#### Additional Considerations:

- Provide necessary view functions,
- Implement a module event system to log whitelist modifications and deposits.
- Allow the admin to transfer or withdraw funds if necessary.
- Write Unit test cases
