# Loyalty Reward Token System
## Overview:
- This system is designed to reward customers with digital tokens that act as loyalty points. These tokens can be earned, redeemed, and expire after a set period.
### Features & Requirements:
- LoyaltyToken → A custom coin that represents reward points.
- Admin Control → Only the business owner can mint new tokens for customers. It’s not directly transferred to the customer, it will be stored somewhere else.
### Customer Functions
- Redeem tokens which admin minted for them.
- Check balance.
- Token Expiry System
- Expired tokens cannot be used.
- At the time of minting the token, the business owner will provide a token expiry second.
- Admin is able to withdraw or burn these expired tokens.
#### Note: Main focus of this practice is to create custom coins, and any operation related to storage uses an object instead of a resource account.
