
#!/bin/bash

# ==============================================================================
# COMPLETE APTOS MULTISIG MANAGEMENT SCRIPT
# ==============================================================================
# This script handles profile creation, multisig setup, module deployment,
# and transaction execution with dynamic sequence number management
# ==============================================================================

# Color definitions for enhanced readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}=================================================================${NC}"
    echo -e "${WHITE}${BOLD}$1${NC}"
    echo -e "${BLUE}=================================================================${NC}"
}

print_step() {
    echo -e "${PURPLE}${BOLD}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_data() {
    echo -e "${WHITE}$1${NC}"
}

# Function to extract address from profile
get_address_from_profile() {
    local profile_name=$1
    local addr=$(aptos account list --profile $profile_name 2>/dev/null | grep -o '"addr": "0x[a-fA-F0-9]*"' | cut -d'"' -f4 | head -1)
    
    if [ -z "$addr" ]; then
        print_warning "Could not extract address from profile '$profile_name'"
        return 1
    else
        echo "$addr"
    fi
}

# Function to get next sequence number dynamically
get_next_sequence() {
    local multisig_addr=$1
    local seq=$(aptos move view \
        --function-id 0x1::multisig_account::next_sequence_number \
        --args address:"$multisig_addr" 2>/dev/null | grep -o '[0-9]*' | head -1)
    
    if [ -z "$seq" ]; then
        echo "1"
    else
        echo "$seq"
    fi
}

# Function to check profile existence
check_profile_exists() {
    local profile_name=$1
    if aptos account list --profile $profile_name >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if transaction can be executed
check_execution_status() {
    local multisig_addr=$1
    local seq_num=$2
    print_info "Checking if transaction #$seq_num can be executed..."
    aptos move view \
        --function-id 0x1::multisig_account::can_be_executed \
        --args address:"$multisig_addr" u64:$seq_num
}

# ==============================================================================
# STEP 1: PROFILE CREATION AND SETUP
# ==============================================================================

print_header "PROFILE CREATION AND INITIALIZATION"

# Check if profiles exist, create if they don't
profiles=("default" "two" "three")

for profile in "${profiles[@]}"; do
    print_step "Checking/Creating Profile: $profile"
    
    if check_profile_exists $profile; then
        print_success "Profile '$profile' already exists"
    else
        print_info "Creating new profile '$profile'..."
        aptos init --profile $profile --network testnet
        
        if [ $? -eq 0 ]; then
            print_success "Profile '$profile' created successfully"
        else
            print_error "Failed to create profile '$profile'"
            exit 1
        fi
    fi
done

# Alternative: Use existing profiles if available
print_info "You can also use existing profiles like 'default', 'testnet', etc."

# ==============================================================================
# STEP 2: DYNAMIC ADDRESS EXTRACTION
# ==============================================================================

print_header "DYNAMIC ADDRESS EXTRACTION FROM PROFILES"

print_info "Using default profile"
default_addr=$(get_address_from_profile "default")
if [ $? -eq 0 ]; then
    print_data "Default Profile Address: $default_addr"
    print_info "You can use this as one of your multisig owners"
fi

two_addr=$(get_address_from_profile "two") 
if [ $? -ne 0 ]; then
    two_addr=$bbb_addr_static
    print_warning "Using static address for BBB: $two_addr"
else
    print_success "Dynamic address for BBB: $two_addr"
fi

three_addr=$(get_address_from_profile "three")
if [ $? -ne 0 ]; then
    three_addr=$ccc_addr_static  
    print_warning "Using static address for CCC: $three_addr"
else
    print_success "Dynamic address for CCC: $three_addr"
fi


# Display final addresses
print_step "Final Address Configuration:"
print_data "Default Address: $default_addr"
print_data "BBB Address: $two_addr"
print_data "CCC Address: $three_addr"

# ==============================================================================
# STEP 3: MULTISIG WALLET CREATION
# ==============================================================================

print_header "MULTISIG WALLET CREATION (2-OF-3)"

print_step "Creating multisig wallet with 2 required signatures"
# Use the first profile (default) or default profile for multisig creation
multisig_creation_profile="default"
if ! check_profile_exists $multisig_creation_profile; then
    multisig_creation_profile="default"
    print_info "Using 'default' profile for multisig creation"
fi

aptos multisig create \
    --additional-owners $two_addr \
    --additional-owners $three_addr \
    --num-signatures-required 2 \
    --profile $multisig_creation_profile \
    --assume-yes

if [ $? -eq 0 ]; then
    print_success "Multisig wallet created successfully!"
else
    print_error "Failed to create multisig wallet"
    exit 1
fi

echo "Enter the multisig address with prefix 0x: "
read multisig_addr

# Set multisig address (this should be obtained from the creation output)
print_data "Multisig Address: $multisig_addr"

# ==============================================================================
# STEP 4: MULTISIG WALLET VERIFICATION
# ==============================================================================

print_header "MULTISIG WALLET VERIFICATION"

print_step "Checking required signatures"
aptos move view \
    --function-id 0x1::multisig_account::num_signatures_required \
    --args address:"$multisig_addr"

print_step "Checking multisig owners"
aptos move view \
    --function-id 0x1::multisig_account::owners \
    --args address:"$multisig_addr"

print_step "Checking last resolved sequence number"
aptos move view \
    --function-id 0x1::multisig_account::last_resolved_sequence_number \
    --args address:"$multisig_addr"

# ==============================================================================
# STEP 5: MODULE DEPLOYMENT PREPARATION
# ==============================================================================

print_header "MODULE DEPLOYMENT PREPARATION"

print_step "Building publication payload"
aptos move build-publish-payload \
    --named-addresses my_addrx=$multisig_addr \
    --json-output-file publication.json \
    --assume-yes

if [ $? -eq 0 ]; then
    print_success "Publication payload created: publication.json"
else
    print_error "Failed to create publication payload"
    exit 1
fi

# ==============================================================================
# STEP 6: MODULE DEPLOYMENT VIA MULTISIG
# ==============================================================================

print_header "MODULE DEPLOYMENT VIA MULTISIG"

# Get current sequence number dynamically
current_seq=$(get_next_sequence $multisig_addr)
print_info "Creating deployment transaction (Sequence #$current_seq)"

print_step "Creating multisig transaction for module deployment"
aptos multisig create-transaction \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --store-hash-only \
    --assume-yes

print_step "Checking pending transactions"
aptos move view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

print_step "Verifying deployment proposal"
aptos multisig verify-proposal \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --sequence-number $current_seq

print_step "Approving deployment with BBB profile (1/2 signatures)"
aptos multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number $current_seq \
    --profile two \
    --assume-yes

# Check execution status
check_execution_status $multisig_addr $current_seq

print_step "Executing module deployment"
aptos multisig execute-with-payload \
    --multisig-address $multisig_addr \
    --json-file publication.json \
    --max-gas 10000 \
    --assume-yes

if [ $? -eq 0 ]; then
    print_success "Module deployed successfully!"
else
    print_error "Module deployment failed"
fi

print_step "Verifying multisig account resources"
aptos account list --account $multisig_addr

# ==============================================================================
# STEP 7: FUNCTION TRANSACTION CREATION AND EXECUTION
# ==============================================================================

print_header "CREATING AND EXECUTING FUNCTION TRANSACTIONS"

# Get next sequence number for function call
function_seq=$(get_next_sequence $multisig_addr)
print_info "Creating function transaction (Sequence #$function_seq)"

print_step "Creating mint transaction"
aptos multisig create-transaction \
    --multisig-address $multisig_addr \
    --function-id $multisig_addr::FA::mint_to \
    --args \
        address:$two_addr \
        u64:1010 \
        u64:1764579073 \
    --assume-yes

print_step "Checking next sequence number"
next_seq=$(get_next_sequence $multisig_addr)
print_info "Next sequence number: $next_seq"

print_step "Checking pending transactions"
aptos move view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"

# Check execution status before approval
check_execution_status $multisig_addr $function_seq

print_step "Approving mint transaction with BBB profile"
aptos multisig approve \
    --multisig-address $multisig_addr \
    --sequence-number $function_seq \
    --profile two \
    --assume-yes

# Check execution status after approval
check_execution_status $multisig_addr $function_seq

print_step "Executing mint transaction"
aptos multisig execute \
    --multisig-address $multisig_addr \
    --profile two \
    --max-gas 10000 \
    --assume-yes

if [ $? -eq 0 ]; then
    print_success "Mint transaction executed successfully!"
else
    print_error "Mint transaction execution failed"
fi

# ==============================================================================
# STEP 8: VERIFICATION AND BALANCE CHECK
# ==============================================================================

print_header "FINAL VERIFICATION"

print_step "Checking balance after mint operation"
aptos move view \
    --function-id $multisig_addr::FA::balance_of \
    --args address:$two_addr

print_success "All operations completed!"

# ==============================================================================
# SCRIPT COMPLETION SUMMARY
# ==============================================================================

print_header "SCRIPT EXECUTION SUMMARY"
print_success "✓ Profiles created (default, two, three)"
print_success "✓ Multisig wallet created (2-of-3): $multisig_addr"
print_success "✓ Module deployed via multisig"
print_success "✓ Function transactions executed"
print_success "✓ Balance verification completed"

print_info "Multisig Address: $multisig_addr"
print_info "Configuration: 2-of-3 signatures required"
print_info "Owners: $default_addr, $two_addr, $three_addr"

echo -e "${GREEN}${BOLD}🎉 Multisig operations completed successfully! 🎉${NC}"