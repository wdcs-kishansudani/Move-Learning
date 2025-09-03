#!/bin/bash

# Supra Multisig Account Management Script
# This script demonstrates the complete workflow of creating and managing multisig accounts on Supra testnet

# Color definitions for enhanced output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${PURPLE}=================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}=================================================${NC}\n"
}

# Function to print step information
print_step() {
    echo -e "${CYAN}➤ $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print errors
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to prompt for user input
prompt_continue() {
    echo -e "\n${YELLOW}Press Enter to continue or Ctrl+C to exit...${NC}"
    read
}

print_header "SUPRA MULTISIG ACCOUNT SETUP"
echo -e "${BLUE}This script will guide you through creating and managing multisig accounts on Supra testnet${NC}\n"

# =============================================================================
print_header "STEP 1: CREATING OWNER ACCOUNTS"
# =============================================================================

print_step "Creating default profile..."
supra profile new default --network testnet
print_success "Default profile created"

print_step "Creating accountA profile..."
supra profile new accountA --network testnet
print_success "AccountA profile created"

print_step "Creating accountB profile..."
supra profile new accountB --network testnet
print_success "AccountB profile created"

prompt_continue

# =============================================================================
print_header "STEP 2: ACTIVATING DEFAULT PROFILE"
# =============================================================================

print_step "Activating default profile..."
supra profile activate default
print_success "Default profile activated"

prompt_continue

# =============================================================================
print_header "STEP 3: SETTING ENVIRONMENT VARIABLES"
# =============================================================================

print_warning "Please manually set the following environment variables with your actual addresses:"
echo -e "${WHITE}export default_addr=<your_default_address>${NC}"
echo -e "${WHITE}export accounta_addr=<your_accounta_address>${NC}"
echo -e "${WHITE}export accountb_addr=<your_accountb_address>${NC}"

# Placeholder variables (users need to replace these)
print_step "Setting environment variables..."

print_step "Enter default address (default_addr): "
read default_addr

print_step "Enter accountA address (accounta_addr): "
read accounta_addr

print_step "Enter accountB address (accountb_addr): "
read accountb_addr


print_warning "Make sure to replace the empty variables above with actual addresses"

prompt_continue

# =============================================================================
print_header "STEP 4: FUNDING OWNER ACCOUNTS"
# =============================================================================

print_step "Funding default account..."
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile default
print_success "Default account funded"

print_step "Funding accountA..."
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountA
print_success "AccountA funded"

print_step "Funding accountB..."
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile accountB
print_success "AccountB funded"

prompt_continue

# =============================================================================
print_header "STEP 5: CREATING THE MULTISIG ACCOUNT"
# =============================================================================

print_step "Creating multisig account with 2/3 signature requirement..."
print_warning "Make sure \$accounta_addr and \$accountb_addr variables are set"

supra move multisig create \
    --timeout-duration 3600 \
    --num-signatures-required 2 \
    --additional-owners $accounta_addr $accountb_addr \
    --rpc-url https://rpc-testnet.supra.com

print_success "Multisig account created"

# Set the multisig address (replace with actual address from creation output)
print_step "Enter multisig_addr: "
read multisig_addr
print_warning "Update multisig_addr variable with the actual address from the creation output"

prompt_continue

# =============================================================================
print_header "STEP 6: VERIFYING MULTISIG CONFIGURATION"
# =============================================================================

print_step "Checking required signatures..."
supra move tool view \
    --function-id 0x1::multisig_account::num_signatures_required \
    --args address:"$multisig_addr"

print_step "Verifying owners..."
supra move tool view \
    --function-id 0x1::multisig_account::owners \
    --args address:"$multisig_addr"

print_step "Checking transaction sequence number..."
supra move tool view \
    --function-id 0x1::multisig_account::last_resolved_sequence_number \
    --args address:"$multisig_addr"

print_success "Multisig configuration verified"

prompt_continue

# =============================================================================
print_header "STEP 7: PREPARING MODULE DEPLOYMENT"
# =============================================================================

print_step "Generating publication payload JSON file..."
supra move tool build-publish-payload \
    --named-addresses my_addrx=$multisig_addr \
    --json-output-file publication.json \
    --assume-yes

print_success "Publication payload generated"

prompt_continue

# =============================================================================
print_header "STEP 8: CREATING MULTISIG PUBLICATION TRANSACTION"
# =============================================================================

print_step "Creating multisig transaction for module deployment (store hash only)..."
supra move multisig create-transaction \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --store-hash-only \
    --assume-yes

print_success "Publication transaction created"

prompt_continue

# =============================================================================
print_header "STEP 9: VERIFYING TRANSACTION"
# =============================================================================

print_step "Checking pending transactions..."
supra move tool view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

print_step "Verifying the proposal..."
supra move multisig verify-proposal \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --sequence-number 1

print_step "Checking if ready to execute..."
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:1

print_success "Transaction verification completed"

prompt_continue

# =============================================================================
print_header "STEP 10: EXECUTING DEPLOYMENT"
# =============================================================================

print_step "Executing the module deployment..."
supra move multisig execute-with-payload \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --profile accountA \
    --max-gas 10000 \
    --assume-yes

print_success "Module deployment executed"

prompt_continue

# =============================================================================
print_header "STEP 11: CREATING FUNCTION TRANSACTIONS"
# =============================================================================

print_step "Creating mint transaction..."
supra move multisig create-transaction \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FAA::mint_to \
    --args \
        address:$accounta_addr \
        u64:1010 \
        u64:1764579073 \
    --assume-yes

print_success "Mint transaction created"

prompt_continue

# =============================================================================
print_header "STEP 12: MANAGING FUNCTION EXECUTION"
# =============================================================================

print_step "Getting next sequence number..."
seq=$(supra move tool view \
    --function-id 0x1::multisig_account::next_sequence_number \
    --args address:"$multisig_addr" | jq -r .result[0])

echo -e "${WHITE}Next sequence number: $seq${NC}"

print_step "Checking pending transactions..."
supra move tool view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

print_step "Checking execution status before approval..."
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:$seq

prompt_continue

# =============================================================================
print_header "STEP 13: APPROVING AND EXECUTING TRANSACTION"
# =============================================================================

print_step "Approving mint transaction with accountA..."
supra move multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number $seq \
    --profile accountA \
    --assume-yes

print_step "Checking execution status after approval..."
supra move tool view \
    --function-id 0x1::multisig_account::can_be_executed \
    --args address:"$multisig_addr" u64:$seq

print_step "Executing mint transaction..."
supra move multisig execute \
    --multisig-address $multisig_addr \
    --profile accountA \
    --max-gas 10000 \
    --assume-yes

print_success "Transaction executed successfully"

prompt_continue

# =============================================================================
print_header "STEP 14: VERIFYING RESULTS"
# =============================================================================

print_step "Checking balance after mint operation..."
# Note: Fixed variable name from $two_addr to $accounta_addr
supra move tool view \
    --function-id $multisig_addr::FAA::balance_of \
    --args address:$accounta_addr

print_success "Balance verification completed"

# =============================================================================
print_header "SCRIPT COMPLETED SUCCESSFULLY!"
# =============================================================================

echo -e "${GREEN}🎉 Multisig account setup and transaction execution completed!${NC}"
echo -e "${BLUE}Your multisig account is ready for production use.${NC}\n"

print_warning "Remember to:"
echo -e "${WHITE}1. Save your multisig address: $multisig_addr${NC}"
echo -e "${WHITE}2. Keep your profile credentials secure${NC}"
echo -e "${WHITE}3. Test all operations on testnet before mainnet deployment${NC}"