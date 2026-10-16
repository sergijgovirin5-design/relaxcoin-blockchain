# R2R Ecosystem Complete Deployment Guide

## Overview

The R2R ecosystem consists of:
1. **Smart Contracts**: R2RTokenFactory (ERC-20 token factory with 70/30 fee split)
2. **Mobile Wallet (Thone)**: .NET MAUI app with embedded WalletConnect interface
3. **Desktop Wallet (PC)**: C# desktop application (build-ready)
4. **WalletConnect Integration**: Allows users to sign transactions via external wallets

## Smart Contract Setup

### Step 1: Install Dependencies

```bash
cd E:\Relax_Corp
npm install
```

### Step 2: Verify Contract Compilation

```bash
npm run compile
```

Expected output: `Nothing to compile` (artifacts already exist)

### Step 3: Deploy to Local Network

Start Hardhat node:
```bash
npx hardhat node
```

In another terminal, deploy:
```bash
npm run deploy
```

Capture the printed `R2RTokenFactory` address (e.g., `0x...`) for mobile/desktop wallet configuration.

### Step 4: Run Contract Tests

```bash
npm test
```

Expected output: 3 passing tests for token allocation, payment splits, and validation.

## Mobile Wallet (Thone) Setup

### Prerequisites
- Windows 10+ (for development)
- .NET 8.0 SDK
- Android SDK (for Android deployment)
- Node.js 18+ (for embedded page build)

### Step 1: Build Embedded WalletConnect Page

```powershell
Push-Location E:\Relax_Corp\Sait_Storinck\Metamasc_Conect\Thone\wallet-connect
npm install
npm run build
Pop-Location
```

This generates `Resources\Raw\walletapp.html` (~2 MB) containing:
- WalletConnect Ethereum provider (v2.17.1)
- ethers.js library (v6.14.0)
- R2R token creation and payment UI

### Step 2: Build Mobile App

**Windows Desktop:**
```powershell
cd E:\Relax_Corp\Sait_Storinck\Metamasc_Conect\Thone
dotnet build Thone.csproj -f net8.0-windows10.0.19041.0
```

**Android:**
```powershell
cd E:\Relax_Corp\Sait_Storinck\Metamasc_Conect\Thone
dotnet build Thone.csproj -f net8.0-android -c Release
# Or use Visual Studio: open Thone.csproj and deploy to Android device
```

### Step 3: Configure Mobile App

Launch the app and configure:

1. **Reown Project ID** (from https://dashboard.reown.com)
   - Create an account and project
   - Copy public Project ID

2. **RPC Endpoint** 
   - Must be HTTPS reachable by both phone and wallet
   - Example: `https://eth-mainnet.alchemyapi.io/v2/YOUR-API-KEY`
   - Local RPC must use actual IP address, not `127.0.0.1`

3. **Chain ID**
   - Local development: `271828` (Hardhat chainId)
   - Mainnet: use actual network chain ID

4. **Factory Address**
   - From `npm run deploy` output
   - Example: `0x...` (R2RTokenFactory address)

5. **Native Symbol** (for display)
   - Local/test: `ETH`
   - Can be customized per network

### Step 4: Test Token Creation

1. Tap "Connect wallet" → select wallet (MetaMask, Trust, etc.)
2. Approve WalletConnect connection in wallet app
3. Create token:
   - Name: e.g., "Creator Token"
   - Symbol: e.g., "CRT"
   - Supply: e.g., "1000"
4. App shows 70/30 split allocation
5. Confirm in connected wallet
6. Pay gas fee in network's native coin

Result: Creator receives 700 CRT, platform wallet receives 300 CRT

### Step 5: Test Token Payment

1. Transfer some tokens to a test account (via connected wallet)
2. Select that token in the app
3. Choose "Pay with token"
4. Enter recipient address and amount
5. App shows 70/30 payment split
6. Confirm in connected wallet

Result: Recipient receives 70% of amount, platform wallet receives 30%

## Desktop Wallet (PC) Setup

### Prerequisites
- Windows 10+
- .NET 8.0 SDK
- Visual Studio 2022 Community (optional)

### Build

Navigate to `E:\Relax_Corp\Sait_Storinck\Metamasc_Conect\PC` and:

```powershell
dotnet build PC.csproj -f net8.0-windows10.0.19041.0 -c Release
```

(Code is unchanged from previous sessions; rebuild should succeed)

## Network Configuration Examples

### Local Development (Hardhat)
```
RPC URL:       http://localhost:8545
Chain ID:      271828
Native Symbol: ETH
Factory:       (from npm run deploy)
Project ID:    (create at dashboard.reown.com)
```

### Testnet (e.g., Ethereum Sepolia)
```
RPC URL:       https://sepolia.infura.io/v3/YOUR-API-KEY
Chain ID:      11155111
Native Symbol: ETH
Factory:       (deploy to Sepolia first)
Project ID:    (create at dashboard.reown.com)
```

### Production (Ethereum Mainnet)
```
RPC URL:       https://eth-mainnet.alchemyapi.io/v2/YOUR-API-KEY
Chain ID:      1
Native Symbol: ETH
Factory:       (deploy to mainnet first)
Project ID:    (create at dashboard.reown.com)
```

## Security Checklist

- [ ] Never paste private keys or seed phrases into the mobile app
- [ ] Verify RPC URL is HTTPS (no embedded credentials in URL)
- [ ] Verify factory address before each transaction
- [ ] Verify chain ID matches expected network
- [ ] Review token supply, recipient, and 70/30 split in app before signing
- [ ] Approve transaction *in your connected wallet*, not in the app
- [ ] Monitor wallet activity for unauthorized tokens or payments
- [ ] Keep Project ID confidential (it's a public identifier, but don't share URLs)

## Troubleshooting

### Mobile app won't connect to wallet
- Verify Reown Project ID is correct
- Check internet connection
- Ensure wallet app is installed and has same chain configured
- Try a different wallet (MetaMask → Trust, etc.)

### Transaction fails with "invalid recipient" or "amount zero"
- Verify recipient address is not `0x0` or the platform wallet address
- Verify amount > 0
- Verify connected account has sufficient balance and gas

### "Could not resolve factory token registry" error
- Verify factory address is correct
- Ensure factory is deployed on the configured chain
- Check chain ID matches factory deployment

### RPC connection errors
- Verify RPC URL is HTTPS and reachable
- Check internet connection
- Try a different RPC provider
- For local dev: ensure Hardhat node is running on actual IP (not `127.0.0.1` for mobile)

### npm install hangs during WalletConnect build
- This may happen on slow internet or with antivirus interference
- Stop the process (Ctrl+C) and retry
- If persistent, check node/npm versions: `node -v`, `npm -v`

## File Structure

```
E:\Relax_Corp\
├── contracts/
│   └── R2RTokenFactory.sol           # Smart contracts
├── test/
│   └── R2RTokenFactory.test.js       # Contract tests
├── Sait_Storinck/Metamasc_Conect/
│   ├── PC/                           # Desktop wallet (C#)
│   └── Thone/                        # Mobile wallet (MAUI)
│       ├── wallet-connect/
│       │   ├── walletapp.js          # WalletConnect logic
│       │   ├── walletapp.template.html
│       │   ├── build.mjs             # Build script
│       │   └── package.json
│       ├── MainPage.xaml             # Mobile UI
│       ├── MainPage.xaml.cs          # WebView integration
│       ├── Thone.csproj              # Project file
│       └── Resources/Raw/walletapp.html (generated)
├── package.json                      # Node dependencies (contracts)
├── hardhat.config.js                 # Hardhat configuration
├── README.md                         # Project overview
└── DEPLOYMENT.md                     # This file
```

## Monitoring and Logs

### Smart Contract Events
Listen for `TokenCreated` and `PaymentProcessed` events via ethers.js:

```javascript
factory.on("TokenCreated", (creator, token, name, symbol, supply, commission) => {
  console.log(`Token created: ${name} (${symbol}) by ${creator}`);
});
```

### Mobile App Logs
- Status messages appear in the mobile UI
- WalletConnect connection events logged to browser console (F12 in WebView)

### Transaction Status
- Track via blockchain explorer using tx hash
- Confirm token registry with `factory.isCreatedToken(tokenAddress)`
- Verify balances with `token.balanceOf(account)`

## Support

For issues or questions:
1. Check this deployment guide
2. Review test files for example usage
3. Check WalletConnect docs: https://docs.walletconnect.com
4. Check ethers.js docs: https://docs.ethers.org

---

**Last Updated**: 2025-01-10  
**Status**: All components compiled and verified ✓
