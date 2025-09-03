# Supra Multisig Account Management

This repository contains a comprehensive shell script and documentation for creating and managing multisig accounts on the Supra blockchain testnet.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Script Features](#script-features)
- [Step-by-Step Guide](#step-by-step-guide)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Contributing](#contributing)

## 🚀 Overview

This project provides an automated workflow for:

- Creating multiple Supra blockchain profiles
- Setting up multisig accounts with configurable signature requirements
- Deploying smart contracts through multisig transactions
- Managing function calls and transaction approvals
- Verifying account states and balances

## 📋 Prerequisites

Before running the script, ensure you have:

### Required Software

- **Supra CLI**: Install the Supra command-line interface
  ```bash
  # Installation instructions for Supra CLI
  curl -L https://github.com/Entropy-Foundation/supra-cli/releases/latest/download/supra-cli-install.sh | bash
  ```
- **jq**: JSON processor for parsing command outputs

  ```bash
  # On Ubuntu/Debian
  sudo apt-get install jq

  # On macOS
  brew install jq
  ```

- **Bash**: Version 4.0 or higher

### Network Access

- Stable internet connection
- Access to Supra testnet RPC: `https://rpc-testnet.supra.com`

## 🎯 Quick Start

1. **Clone or download the script**:

   ```bash
   wget https://your-repo/supra-multisig-setup.sh
   chmod +x supra-multisig-setup.sh
   ```

2. **Run the script**:

   ```bash
   ./supra-multisig-setup.sh
   ```

3. **Follow the interactive prompts** - the script will guide you through each step

## ✨ Script Features

### Color-Coded Output

- 🟢 **Green**: Success messages
- 🟡 **Yellow**: Warnings and prompts
- 🔵 **Blue**: Information and headers
- 🟣 **Purple**: Section dividers
- 🔴 **Red**: Error messages

### Interactive Flow

- Step-by-step execution with user confirmation
- Automatic pausing between major operations
- Clear progress indicators

### Comprehensive Coverage

- Account creation and funding
- Multisig configuration and verification
- Smart contract deployment
- Transaction management and approval

## 📝 Step-by-Step Guide

### Phase 1: Account Setup

1. **Profile Creation**: Creates three profiles (default, accountA, accountB)
2. **Profile Activation**: Sets the default profile as active
3. **Address Configuration**: Prompts for setting environment variables
4. **Account Funding**: Funds all accounts using the testnet faucet

### Phase 2: Multisig Configuration

5. **Multisig Creation**: Creates a 2-of-3 multisig account
6. **Configuration Verification**: Validates signature requirements and owners
7. **State Checking**: Verifies transaction sequence numbers

### Phase 3: Smart Contract Operations

8. **Payload Generation**: Creates deployment payload
9. **Transaction Creation**: Sets up multisig deployment transaction
10. **Proposal Verification**: Validates transaction proposals
11. **Contract Deployment**: Executes the smart contract deployment

### Phase 4: Function Management

12. **Function Transactions**: Creates mint function calls
13. **Approval Process**: Manages transaction approvals
14. **Execution**: Completes function execution
15. **Balance Verification**: Confirms operation results

## ⚙️ Configuration

### Environment Variables

Before running the script, you'll need to set these variables with your actual addresses:

```bash
# Replace with actual addresses from profile creation
export default_addr="0x..."
export accounta_addr="0x..."
export accountb_addr="0x..."
export multisig_addr="0x..."
```

### Multisig Parameters

The script creates a multisig with these default settings:

- **Timeout Duration**: 3600 seconds (1 hour)
- **Required Signatures**: 2 out of 3
- **Max Gas**: 10,000 units

To modify these settings, edit the relevant sections in the script:

```bash
supra move multisig create \
    --timeout-duration 7200 \        # Change timeout
    --num-signatures-required 3 \    # Change required signatures
    --additional-owners $accounta_addr $accountb_addr \
    --rpc-url https://rpc-testnet.supra.com
```

## 🔧 Troubleshooting

### Common Issues

#### 1. "Profile already exists" Error

```bash
# Solution: Remove existing profiles
supra profile delete <profile_name>
```

#### 2. "Insufficient funds" Error

```bash
# Solution: Fund account manually
supra move account fund-with-faucet --rpc-url https://rpc-testnet.supra.com --profile <profile_name>
```

#### 3. "Invalid address format" Error

- Ensure addresses start with `0x`
- Verify address length (64 characters after `0x`)
- Check for typos in environment variables

#### 4. "Transaction timeout" Error

- Increase timeout duration in multisig creation
- Check network connectivity
- Retry the operation

### Debug Mode

Run the script with debug output:

```bash
bash -x supra-multisig-setup.sh
```

### Log Files

The script outputs can be redirected for debugging:

```bash
./supra-multisig-setup.sh 2>&1 | tee setup.log
```

## 🔒 Security Best Practices

### Key Management

- **Never share private keys**: Keep profile credentials secure
- **Use hardware wallets**: For production deployments
- **Backup profiles**: Store encrypted backups of profile configurations

### Network Security

- **Use HTTPS endpoints**: Always use secure RPC endpoints
- **Verify transactions**: Double-check all transaction details before approval
- **Test on testnet**: Thoroughly test before mainnet deployment

### Multisig Management

- **Distribute keys**: Ensure multisig owners are independent parties
- **Set appropriate timeouts**: Balance security with operational efficiency
- **Monitor transactions**: Regularly check pending and executed transactions

## 📊 Monitoring and Verification

### Check Account Status

```bash
# View multisig configuration
supra move tool view \
    --function-id 0x1::multisig_account::num_signatures_required \
    --args address:"$multisig_addr"

# Check pending transactions
supra move tool view \
    --function-id 0x1::multisig_account::get_pending_transactions \
    --args address:"$multisig_addr"
```

### Balance Verification

```bash
# Check token balance
supra move tool view \
    --function-id $multisig_addr::FAA::balance_of \
    --args address:$target_address
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Development Setup

```bash
git clone https://github.com/your-repo/supra-multisig-setup.git
cd supra-multisig-setup
chmod +x supra-multisig-setup.sh
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Open an issue in this repository
- Check the [Supra documentation](https://docs.supra.com)
- Join the Supra community Discord

## 🔗 Useful Links

- [Supra Official Documentation](https://docs.supra.com)
- [Supra Testnet Explorer](https://testnet.suprascan.io)
- [Supra CLI Documentation](https://github.com/Entropy-Foundation/supra-cli)
- [Multisig Best Practices](https://docs.supra.com/multisig)

---

**⚠️ Disclaimer**: This script is provided for educational and development purposes. Always test thoroughly on testnet before using on mainnet. The authors are not responsible for any loss of funds or assets.
