# Notes

- In move `simple_map` doen't have default value so directly accessing the key without setting anything will result in error.

  - First need to check `simple_map::contains_key` if not then add the key.

- Same account can hold multiple object of same fungible asset
- Object by default are transferable and can own multiple resources.
- ConstructorRef can ben used to generate other permission. ConstructorRef can not be stored and will be destroyed by end of the transaction.
- Creating object is like creating Box, get a box, put things inside box and transfer box (can be nested).
- One object can hold another object (can be multiple different object), transfering main object to another will transfer nested object also.
- Public function will not be directly callable by users to do that it need to have entry function. (sending data in transaction).
