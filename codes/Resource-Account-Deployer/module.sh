# Calculate Resource Account Address First
aptos account derive-resource-account-address --address default --seed 1235

# change my_addrx to your resource account address

# deploy using resource account
aptos move create-resource-account-and-publish-package --seed 1235 --address-name NFT --profile default --named-addresses source_addr=default

# 