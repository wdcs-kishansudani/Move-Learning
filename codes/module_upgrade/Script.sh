mkdir my_module
cd my_module
aptos move init --name my_module

# Create new account
aptos init

# Fund account on testnet
aptos account fund-with-faucet --account default

# Deploy the Module
aptos move publish --named-addresses my_module=default


# set message
aptos move run \
  --function-id default::counter::set_message

# Update Module Code

# Compile Updated Module
aptos move compile

# Re-publish (if original was deployed without object)
aptos move publish --named-addresses my_module=default

# or

# Using upgrade-object-package (Recommended)
# First, find your package object address from the initial deployment
# Look for "Code will be published at" in your initial deploy output
aptos move upgrade-object-package \
  --object-address <PACKAGE_OBJECT_ADDRESS> \
  --named-addresses my_module=default

# Using governance (for production)
aptos move create-upgrade-proposal \
  --named-addresses my_module=default \
  --metadata-url "ipfs://..." # Optional metadata


# fetch
aptos move view \
  --function-id default::my_module::get_message \
  --args address:default