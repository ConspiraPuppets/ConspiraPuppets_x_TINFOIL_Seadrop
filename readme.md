# NFT-to-Token Launch System with Uniswap V3

Complete deployment and operation guide for an NFT collection that automatically distributes tokens to minters and creates a permanent Uniswap V3 liquidity pool.

---

## 📋 Table of Contents

- [System Overview](#system-overview)
- [Contract Architecture](#contract-architecture)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Deployment Process](#deployment-process)
- [Post-Deployment Operations](#post-deployment-operations)
- [LP Verification & Fee Collection](#lp-verification--fee-collection---complete-guide)
  - [Verify LP is Working](#part-1-verify-your-lp-is-working)
  - [Understanding Fees](#part-2-understanding-fees)
  - [Check Uncollected Fees](#part-3-check-uncollected-fees)
  - [Collect Fees (3-Step Process)](#part-4-collect-fees-3-step-process)
  - [Convert WETH to ETH](#part-5-optional---convert-weth-to-eth)
  - [Set Up Regular Collection](#part-7-set-up-regular-fee-collection)
  - [Common Mistakes](#common-mistakes-to-avoid)
  - [FAQ](#frequently-asked-questions)
- [Emergency Functions](#emergency-functions)
- [Important Notes](#important-notes)
- [Troubleshooting](#troubleshooting)
- [Testing Checklist](#testing-checklist)
- [Production Launch Checklist](#production-launch-checklist)
- [Quick Reference](#quick-reference)

---

## 🎯 System Overview

This system combines three smart contracts to create a complete NFT launch with automatic token distribution and permanent liquidity:

### Key Features
- **Automatic Token Distribution**: Every NFT minted distributes tokens to the minter
- **Auto-Complete Trigger**: When max NFT supply is reached, system automatically prepares for LP creation
- **Permanent Liquidity Lock**: Uniswap V3 position is locked forever (cannot be withdrawn)
- **Owner Fee Collection**: Only the contract owner can collect trading fees from the LP
- **50/50 Fund Split**: Half of collected ETH goes to LP, half remains as operational funds
- **Emergency Recovery**: Built-in functions to recover stuck funds if LP creation fails

### Default Configuration
```
NFT Max Supply: 3,333
Token Total Supply: 3,330,000,000 (3.33B)
Distribution: 50% to NFT holders, 50% to LP
Tokens per NFT: ~1,000,000
Uniswap V3 Fee Tier: 0.3%
LP Range: Full range (ticks -887220 to 887220)
```

---

## 🏗️ Contract Architecture

### Three Core Contracts

#### 1. **TinfoilToken.sol** (ERC-20)
- Custom token with trading controls
- Minting restricted to NFT contract only
- Trading disabled until LP is created
- Whitelist system for LP and owner

#### 2. **ConspiraPuppets.sol** (ERC-721 + SeaDrop)
- NFT contract using SeaDrop for minting
- Automatically distributes tokens on every mint
- Controls LP creation timing
- Owner-only fee collection functions
- Emergency recovery functions

#### 3. **LPManager.sol**
- Creates and locks Uniswap V3 position
- Dynamic price calculation based on ETH/token ratio
- Owned by NFT contract (which you own)
- Collects fees from Uniswap position

### Ownership Chain
```
You (EOA)
  └─ Own ConspiraPuppets.sol
      └─ Owns LPManager.sol
          └─ Owns Uniswap V3 Position NFT
```

---

## ✅ Prerequisites

### Required Tools
```bash
# Foundry (for compilation and deployment)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Cast (included with Foundry)
# Used for contract interactions
```

### Environment Setup
```bash
# Create .env file with your private key
echo "PRIVATE_KEY=your_private_key_here" > .env

# Set your RPC URL (or use public Base RPC)
export BASE_RPC_URL="https://mainnet.base.org"
# Or use a provider like Alchemy/Infura
```

### Wallet Requirements
- **Deployer wallet** must have ETH on Base for:
  - Deployment gas (~$10-20 depending on gas prices)
  - Funding the NFT contract (0.1 ETH minimum recommended)
  
### OpenSea SeaDrop
- SeaDrop contract on Base: `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`
- You'll configure drop settings in OpenSea Studio after deployment

---

## ⚙️ Configuration

### Edit Deploy.s.sol

**CRITICAL: Update these values in `script/Deploy.s.sol` before deploying:**

```solidity
// NFT Configuration
string memory name = "YourCollectionName";
string memory symbol = "SYMBOL";
uint256 maxSupply = 3333;

// Token Configuration  
string memory tokenName = "YourTokenName";
string memory tokenSymbol = "TOKEN";
uint256 totalTokenSupply = 3_330_000_000 * 10**18; // 3.33B tokens

// Calculate distribution (DON'T CHANGE UNLESS YOU KNOW WHAT YOU'RE DOING)
uint256 tokensPerNFT = (totalTokenSupply / 2) / maxSupply;
uint256 lpTokenAmount = totalTokenSupply / 2;
```

### Production Values Example (ConspiraPuppets)
```solidity
string memory name = "ConspiraPuppets";
string memory symbol = "PUPPET";
uint256 maxSupply = 3333;

string memory tokenName = "ConspiraPuppetsToken";
string memory tokenSymbol = "PUPPET";
uint256 totalTokenSupply = 3_330_000_000 * 10**18;
```

---

## 🚀 Deployment Process

### Step 1: Compile Contracts

```bash
cd ~/path/to/project
forge build
```

**Expected output:** `Compiler run successful!`

---

### Step 2: Deploy to Base Mainnet

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url base \
  --broadcast \
  --verify \
  --private-key $PRIVATE_KEY
```

**Wait 2-3 minutes for:**
- ✅ All 3 contracts deployed
- ✅ All 3 contracts verified on BaseScan
- ✅ "ONCHAIN EXECUTION COMPLETE & SUCCESSFUL"

**⚠️ Common Issue: Rate Limits**
If you get `error code -32000: in-flight transaction limit reached`:
- Wait 5-10 minutes
- Retry the exact same command
- Base has rate limits on rapid transactions

---

### Step 3: Save Contract Addresses

**Copy these from deployment output:**

```bash
export TOKEN=0xYourTokenAddress
export NFT=0xYourNFTAddress
export LP_MANAGER=0xYourLPManagerAddress

# Verify they're saved
echo "Token: $TOKEN"
echo "NFT: $NFT"
echo "LP Manager: $LP_MANAGER"
```

**⚠️ IMPORTANT: Save these addresses somewhere safe!**

---

### Step 4: Configure SeaDrop Payout Address

**🚨 CRITICAL STEP - DO NOT SKIP! 🚨**

**This tells SeaDrop to send ALL mint payments to your NFT contract instead of your wallet.**

**Why this matters:**
- ✅ Mint payments go to NFT contract → Contract has ETH → LP can be created
- ❌ Skip this step → Mint payments go to your wallet → Contract has no ETH → LP creation fails!

```bash
cast send $NFT \
  'updateCreatorPayoutAddress(address,address)' \
  0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 \
  $NFT \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**What this command does:**
- Calls SeaDrop's `updateCreatorPayoutAddress` function
- First argument: SeaDrop contract (0x00005EA00Ac477B1030CE78506496e8C2dE24bf5)
- Second argument: Your NFT contract address ($NFT)
- Result: All mint revenue goes to NFT contract ✅

**Verify it worked:**
```bash
# Check that payout is set correctly
# (Unfortunately no easy view function, but transaction success = it worked)
```

**⚠️ DO THIS BEFORE ANNOUNCING YOUR MINT!**

If users mint before you set this, their ETH goes to your wallet and you'll need to manually send it to the contract.

---

### Step 5: Fund the NFT Contract

**CRITICAL: Use 0.1 ETH minimum for LP creation**

```bash
# Recommended: 0.1 ETH
cast send $NFT \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url base

# For production with higher mint revenue:
# If you expect 22.2 ETH from mint, send that amount
# LP will get half (11.1 ETH), rest is operational funds
```

**Fund Split:**
```
Total sent: 0.1 ETH
├── LP receives: 0.05 ETH (locked forever)
└── Operational: 0.05 ETH (you can withdraw)
```

**Verify balance:**
```bash
cast balance $NFT --rpc-url base
# Should show: 100000000000000000 (0.1 ETH)
```

**⚠️ WARNING: Using less than 0.1 ETH may cause "Price slippage check" errors!**

---

### Step 6: Configure Drop in OpenSea Studio

1. Go to https://opensea.io/studio
2. Import your NFT contract address
3. Configure:
   - Mint price
   - Mint start/end times
   - Max per wallet
   - Allowlist (if applicable)
4. Publish drop

**Users can now mint NFTs and will automatically receive tokens!**

---

## 🎯 Post-Deployment Operations

### After NFT Mint Completes

Once all 3,333 NFTs are minted (or when you're ready to create LP):

---

### Step 7: Mark Mint as Complete

**Option A: Automatic (Recommended)**
- Happens automatically when max NFT supply is reached
- Sets 5-minute countdown for LP creation

**Option B: Manual**
```bash
cast send $NFT \
  'setMintCompleted()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

---

### Step 8: Create Liquidity Pool

**Option A: With 5-Minute Safety Delay (Recommended)**
```bash
# Wait 5 minutes after setMintCompleted, then:
cast send $NFT \
  'createLP()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base \
  --gas-limit 10000000
```

**Option B: Immediate (No Delay)**
```bash
cast send $NFT \
  'createLPImmediate()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base \
  --gas-limit 10000000
```

**⏰ This takes 30-60 seconds. Wait for transaction confirmation!**

---

### Step 9: Verify LP Creation

```bash
# Check if LP was created successfully
cast call $LP_MANAGER "lpCreated()" --rpc-url base
# Should return: 0x0000...0001 (true)

# Get your pool address
cast call $LP_MANAGER "getExpectedLPPair()" --rpc-url base
# Returns: 0x... (your pool address)

# Check trading is enabled
cast call $TOKEN "tradingEnabled()" --rpc-url base
# Should return: 0x0000...0001 (true)
```

**✅ SUCCESS INDICATORS:**
- LP created = true
- Pool address returned
- Trading enabled = true
- Position token ID is non-zero

---

### Step 10: Withdraw Operational Funds

```bash
cast send $NFT \
  'withdrawOperationalFunds()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**This withdraws the 50% of ETH that didn't go to LP.**

For example:
- Sent 0.1 ETH → Get back 0.05 ETH
- Sent 22.2 ETH → Get back 11.1 ETH

---

### Step 11: View Your Pool

**Uniswap Interface (wait ~10-15 minutes for indexing):**
```
https://app.uniswap.org/explore/pools/base/YOUR_POOL_ADDRESS
```

**BaseScan:**
```
https://basescan.org/address/YOUR_POOL_ADDRESS
```

---

## 💰 LP Verification & Fee Collection - Complete Guide

### 📊 PART 1: Verify Your LP is Working

After creating your LP, always verify it's set up correctly:

#### Check LP Status
```bash
# 1. Verify LP was created
cast call $LP_MANAGER "lpCreated()" --rpc-url base
# Expected: 0x0000...0001 (true)

# 2. Get position token ID
cast call $LP_MANAGER "positionTokenId()" --rpc-url base
# Expected: Non-zero number (e.g., 0x00000000...003fb33c)

# 3. Get pool address
export POOL=$(cast call $LP_MANAGER "getExpectedLPPair()" --rpc-url base)
echo "Pool address: $POOL"
# Expected: 0x... (your pool address)

# 4. Verify trading is enabled
cast call $TOKEN "tradingEnabled()" --rpc-url base
# Expected: 0x0000...0001 (true)
```

**✅ All four should return expected values!**

---

#### Check Pool Liquidity
```bash
# Check WETH balance in pool
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  $POOL \
  --rpc-url base
# Expected: ~50000000000000000 (0.05 ETH)

# Check token balance in pool
cast call $TOKEN \
  "balanceOf(address)" \
  $POOL \
  --rpc-url base
# Expected: ~16665000000000000000000 (16,665 tokens)
```

**✅ Both should show liquidity is there!**

---

#### View Your Pool on Uniswap
```bash
echo "View your pool on Uniswap:"
echo "https://app.uniswap.org/explore/pools/base/$POOL"

echo "View on BaseScan:"
echo "https://basescan.org/address/$POOL"
```

**⏰ Note: Takes 10-15 minutes after LP creation for Uniswap to index your pool!**

---

### 🎯 PART 2: Understanding Fees

#### How Uniswap V3 Fees Work

Every trade in your pool generates fees (0.3% of swap amount):
- **Someone buys your token:** Fee paid in WETH (you earn WETH)
- **Someone sells your token:** Fee paid in your token (you earn tokens)

**You own 100% of fees** because you're the only liquidity provider!

Fees accumulate in your Uniswap V3 position until you collect them.

---

#### Generate Fees (For Testing)

To test fee collection, you need some trading activity:

**Option A: Sell some tokens on Uniswap**
1. Go to https://app.uniswap.org/swap
2. Connect your wallet
3. Swap 1,000-2,000 tokens → ETH
4. Fees generated: ~3-6 tokens + ~0.00003 WETH

**Option B: Buy some tokens back**
1. Go to https://app.uniswap.org/swap
2. Swap ETH → Your tokens
3. Buy 1,000 tokens
4. Fees generated: ~0.00003 WETH + ~3 tokens

**⏰ Wait 2-3 minutes after trading for fees to settle!**

---

### 💎 PART 3: Check Uncollected Fees

#### Method 1: Via Uniswap Interface (Easiest)

Once your pool is indexed (~10-15 min after creation):
1. Go to https://app.uniswap.org/pool
2. Connect your wallet
3. Find your position (click "Positions")
4. Look for "Fees earned" section
5. Shows: "X tokens + Y WETH"

**This is the easiest way to see uncollected fees!**

---

#### Method 2: Via Position Contract (Most Accurate)

```bash
# Get complete position details
cast call 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 \
  "positions(uint256)" \
  $(cast call $LP_MANAGER "positionTokenId()" --rpc-url base) \
  --rpc-url base
```

**This returns 12 fields. The last two are uncollected fees:**
- Field 10: `tokensOwed0` (uncollected token fees)
- Field 11: `tokensOwed1` (uncollected WETH fees)

**Example output:**
```
...
0x00000000000000000000000000000000000000000000000000000000000f4240  ← Token fees
0x00000000000000000000000000000000000000000000000000016345785d8a00  ← WETH fees
```

**Convert hex to see actual amounts:**
```bash
# If Field 10 = 0xf4240
echo $((0xf4240))
# Returns: 1000000 (= 1 token with 18 decimals)
```

**If both fields are 0, no fees have been collected yet.**

---

### 🎁 PART 4: Collect Fees (3-Step Process)

**🚨 CRITICAL: Always call the NFT contract, NOT the LP Manager!**

#### Step 1: Collect Fees from Uniswap Position

```bash
cast send $NFT \
  'collectLPFees()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**What happens:**
- Calls Uniswap's `collect()` function on your position
- Moves fees from Uniswap position → LP Manager contract
- Fees are now in LP Manager, ready to withdraw

**Wait for transaction confirmation before proceeding!**

---

#### Step 2: Withdraw WETH Fees to Your Wallet

```bash
cast send $NFT \
  'withdrawLPFeesWETH()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**What happens:**
- Gets WETH from LP Manager
- Transfers WETH to YOUR wallet
- WETH = Wrapped ETH (1 WETH = 1 ETH value)

**Verify you received WETH:**
```bash
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base
# Should show your WETH balance
```

---

#### Step 3: Withdraw Token Fees to Your Wallet

```bash
cast send $NFT \
  'withdrawLPFeesTokens()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**What happens:**
- Gets your tokens from LP Manager
- Transfers tokens to YOUR wallet
- You now own these tokens!

**Verify you received tokens:**
```bash
cast call $TOKEN \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base
# Should show increased token balance
```

---

### 🔄 PART 5: Optional - Convert WETH to ETH

WETH is essentially ETH (1:1 value), but if you want native ETH:

```bash
# Check your WETH balance
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base

# Convert to decimal to see amount
# Example: 0x38d7ea4c68000 = 0.001 ETH

# Unwrap WETH to ETH
cast send 0x4200000000000000000000000000000000000006 \
  'withdraw(uint256)' \
  YOUR_WETH_AMOUNT_IN_WEI \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**Now you have native ETH instead of WETH!**

---

### ✅ PART 6: Verify Fee Collection Completed

#### Check LP Manager is Empty
```bash
# LP Manager should have no WETH
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  $LP_MANAGER \
  --rpc-url base
# Expected: 0 (all withdrawn)

# LP Manager should have no tokens
cast call $TOKEN \
  "balanceOf(address)" \
  $LP_MANAGER \
  --rpc-url base
# Expected: 0 (all withdrawn)
```

#### Check Your Balances Increased
```bash
# Your WETH balance should show collected fees
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base

# Your token balance should show collected fees
cast call $TOKEN \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base
```

#### Check Position Shows Zero Uncollected
```bash
# Check position again
cast call 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 \
  "positions(uint256)" \
  $(cast call $LP_MANAGER "positionTokenId()" --rpc-url base) \
  --rpc-url base

# Fields 10 and 11 should now be 0 (no uncollected fees)
```

**✅ All fees collected and in your wallet!**

---

### 📅 PART 7: Set Up Regular Fee Collection

#### Recommended Collection Schedule

**High Trading Volume:**
- Collect weekly
- More gas but don't miss significant fees
- Good if daily volume > $10,000

**Moderate Trading Volume:**
- Collect bi-weekly or monthly
- Balance gas costs vs fee accumulation
- Good if daily volume $1,000-$10,000

**Low Trading Volume:**
- Collect quarterly or when fees > $50
- Minimize gas costs
- Good if daily volume < $1,000

**Rule of Thumb:** Collect when fees > 5x gas cost (~$10-15 in fees minimum)

---

#### Create a Fee Collection Script

**Save as `collect_fees.sh`:**
```bash
#!/bin/bash
# LP Fee Collection Script

echo "🎁 Starting fee collection process..."
echo ""

echo "Step 1/3: Collecting fees from Uniswap position..."
cast send $NFT 'collectLPFees()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
echo "✅ Fees collected from position"
echo ""

echo "Step 2/3: Withdrawing WETH fees..."
cast send $NFT 'withdrawLPFeesWETH()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
echo "✅ WETH fees withdrawn to wallet"
echo ""

echo "Step 3/3: Withdrawing token fees..."
cast send $NFT 'withdrawLPFeesTokens()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
echo "✅ Token fees withdrawn to wallet"
echo ""

echo "🎉 Fee collection complete!"
echo ""
echo "Check your balances:"
echo "WETH: cast call 0x4200000000000000000000000000000000000006 'balanceOf(address)' YOUR_WALLET --rpc-url base"
echo "Tokens: cast call \$TOKEN 'balanceOf(address)' YOUR_WALLET --rpc-url base"
```

**Make executable and run:**
```bash
chmod +x collect_fees.sh
./collect_fees.sh
```

---

### 🎯 PART 8: Complete Example Workflow

**Scenario: 2 weeks after launch, first fee collection**

```bash
# 1. Check if there are fees to collect
cast call 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 \
  "positions(uint256)" \
  $(cast call $LP_MANAGER "positionTokenId()" --rpc-url base) \
  --rpc-url base
# Fields 10 and 11 show non-zero values → Fees available!

# 2. Collect fees from Uniswap position
cast send $NFT 'collectLPFees()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
# ✅ Transaction confirmed

# 3. Withdraw WETH fees
cast send $NFT 'withdrawLPFeesWETH()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
# ✅ WETH now in your wallet

# 4. Withdraw token fees
cast send $NFT 'withdrawLPFeesTokens()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
# ✅ Tokens now in your wallet

# 5. Verify your new balances
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base
# Shows your WETH fees! 💰

cast call $TOKEN \
  "balanceOf(address)" \
  YOUR_WALLET_ADDRESS \
  --rpc-url base
# Shows your token fees! 💰

# 6. (Optional) Convert WETH to ETH
cast send 0x4200000000000000000000000000000000000006 \
  'withdraw(uint256)' \
  YOUR_WETH_AMOUNT \
  --private-key $PRIVATE_KEY \
  --rpc-url base
# ✅ Now you have native ETH
```

---

### 💡 Pro Tips for Fee Collection

#### Tip 1: Always Check Before Collecting
```bash
# Check uncollected fees first
# Saves gas if no fees have accumulated yet
# Don't waste $2-3 on gas to collect $0.10 in fees
```

#### Tip 2: Batch Your Collections
```
❌ Bad: Collect after every trade (waste gas)
✅ Good: Let fees accumulate, collect weekly/monthly
💰 Best: Collect when fees > 5-10x gas costs
```

#### Tip 3: Track Your Earnings
```
Keep a spreadsheet:
Date       | WETH Collected | Tokens Collected | USD Value | Notes
-----------|---------------|------------------|-----------|-------
2025-01-15 | 0.05 WETH     | 500 tokens       | ~$180     | Week 1
2025-01-22 | 0.03 WETH     | 300 tokens       | ~$110     | Week 2
```

#### Tip 4: Monitor Pool Health
```bash
# Regularly check:
- Trading volume (on Uniswap)
- Liquidity amounts (should stay constant)
- Fee generation rate
- Pool ranking on Uniswap
```

#### Tip 5: Reinvest or Hold Token Fees
```
Option A: Hold tokens (believe in project)
Option B: Sell back into pool (get more WETH)
Option C: Use for marketing/airdrops (grow community)
Option D: Add to personal holdings
```

---

### 🚨 Common Mistakes to Avoid

#### ❌ WRONG: Calling LP Manager Directly
```bash
# This FAILS - ownership error
cast send $LP_MANAGER 'collectFees()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base

Error: "Ownable: caller is not the owner"
```

#### ✅ CORRECT: Call Through NFT Contract
```bash
# This WORKS - proper ownership chain
cast send $NFT 'collectLPFees()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

---

#### ❌ WRONG: Skipping Step 1
```bash
# Trying to withdraw without collecting first
cast send $NFT 'withdrawLPFeesWETH()' ...
# Result: Nothing to withdraw (fees still in position)
```

#### ✅ CORRECT: Always Do All 3 Steps
```bash
# Step 1: Collect from position
cast send $NFT 'collectLPFees()' ...

# Step 2: Withdraw WETH
cast send $NFT 'withdrawLPFeesWETH()' ...

# Step 3: Withdraw tokens
cast send $NFT 'withdrawLPFeesTokens()' ...
```

---

#### ❌ WRONG: Not Verifying
```bash
# Just running commands without checking results
# You might miss errors or think it failed when it succeeded
```

#### ✅ CORRECT: Always Verify Each Step
```bash
# After Step 1, check LP Manager has fees
cast call 0x4200...0006 "balanceOf(address)" $LP_MANAGER --rpc-url base

# After Step 2, check your WETH balance increased
cast call 0x4200...0006 "balanceOf(address)" YOUR_WALLET --rpc-url base

# After Step 3, check your token balance increased
cast call $TOKEN "balanceOf(address)" YOUR_WALLET --rpc-url base
```

---

### 📊 Understanding Fee Math

#### How Fees Are Calculated

```
Every trade pays 0.3% fee to the pool:

Example 1 - Someone buys your token:
- Trader swaps: 0.01 ETH → tokens
- Pool receives: 0.01 WETH
- Fee (0.3%): 0.00003 WETH
- Your share: 0.00003 WETH (100% - you're only LP!)

Example 2 - Someone sells your token:
- Trader swaps: 10,000 tokens → ETH
- Pool receives: 10,000 tokens
- Fee (0.3%): 30 tokens
- Your share: 30 tokens (100% - you're only LP!)

Example 3 - High volume day:
- 100 trades totaling $10,000 volume
- Total fees: $30 (0.3% of $10,000)
- Your share: $30 (100% - you're only LP!)
```

#### You Own 100% of All Fees

**Because you're the only liquidity provider in the pool:**
- ✅ All trading fees belong to you
- ✅ No sharing with other LPs
- ✅ No dilution of fees
- ⚠️ But also: All impermanent loss is yours too

**Impermanent Loss Note:**
- Your position is full-range and permanent
- As price changes, you'll experience impermanent loss
- But you keep earning fees which offset this
- Calculate: Total Earnings = Trading Fees - Impermanent Loss

---

### 🎓 Frequently Asked Questions

**Q: How often should I collect fees?**
A: Depends on trading volume. High volume = weekly. Low volume = monthly. Collect when fees > gas costs (~$10-15 minimum).

**Q: What if I forget to collect for months?**
A: Fees accumulate forever in the position. You can collect anytime - no expiration or loss.

**Q: Can someone else collect my fees?**
A: No. Only you (contract owner) can collect fees through the NFT contract. Position is secured by ownership.

**Q: Do I have to pay gas to collect?**
A: Yes. Each step costs gas (~$2-3 total). That's why you should wait until fees are worth it.

**Q: What's the difference between WETH and ETH?**
A: Same 1:1 value. WETH is "wrapped ETH" (ERC-20 version). You can unwrap WETH to get regular ETH anytime.

**Q: Can I collect only WETH and leave token fees?**
A: Yes! Steps 2 and 3 are independent. Collect what you want, leave the rest.

**Q: What if trading volume is very low?**
A: Fees will be small. Consider collecting quarterly or when fees reach $50+. Don't waste gas on tiny amounts.

**Q: Can I automate fee collection?**
A: Yes, with the bash script provided above. Run it manually or set up a cron job.

**Q: What should I do with collected token fees?**
A: Your choice! Hold, sell back to pool, use for airdrops, or keep as personal holdings.

**Q: Do fees stop accumulating?**
A: No. As long as trading happens, fees accumulate forever. The position is permanent.

**Q: What if I sell/transfer the NFT contract?**
A: New owner gets fee collection rights. Ownership of fees follows contract ownership.

**Q: Can I check fees on my phone?**
A: Yes! View your position on Uniswap mobile app. Shows uncollected fees clearly.

**Q: Will collecting fees affect my liquidity?**
A: No. Collecting fees doesn't touch your liquidity. It only withdraws accumulated trading fees.

---

### 🎉 You're Now an Expert!

**You now know how to:**
- ✅ Verify your LP is working correctly
- ✅ Check uncollected fees multiple ways
- ✅ Execute the 3-step collection process
- ✅ Withdraw WETH and token fees
- ✅ Convert WETH to ETH
- ✅ Set up regular collection schedule
- ✅ Avoid common mistakes
- ✅ Understand fee mathematics
- ✅ Troubleshoot any issues

**Start collecting those fees and building passive income!** 💰💰💰

---

## 🆘 Emergency Functions

### If LP Creation Fails

If `createLP()` fails partway through, you can recover funds:

#### Recover ETH from LP Manager
```bash
cast send $NFT \
  'recoverLPManagerETH()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

#### Recover Tokens from LP Manager
```bash
cast send $NFT \
  'recoverLPManagerTokens(address)' \
  $TOKEN \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

#### Emergency ETH Withdrawal from NFT Contract
```bash
cast send $NFT \
  'emergencyWithdraw()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

---

### Testing Emergency Functions

**You can test these work by:**

1. **Test ETH Recovery:**
```bash
# Send test ETH to LP Manager
cast send $LP_MANAGER \
  --value 0.01ether \
  --private-key $PRIVATE_KEY \
  --rpc-url base

# Recover it
cast send $NFT \
  'recoverLPManagerETH()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

2. **Test Token Recovery:**
```bash
# Send test tokens to LP Manager
cast send $TOKEN \
  'transfer(address,uint256)' \
  $LP_MANAGER \
  1000000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url base

# Recover them
cast send $NFT \
  'recoverLPManagerTokens(address)' \
  $TOKEN \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

---

## ⚠️ Important Notes

### 🚨 MOST CRITICAL: Set Payout Address FIRST!

**BEFORE you announce your mint or let anyone mint:**

```bash
cast send $NFT \
  'updateCreatorPayoutAddress(address,address)' \
  0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 \
  $NFT \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**Why this matters:**
- This makes mint payments go to your NFT contract
- Without this, payments go to your wallet
- Contract needs ETH to create LP
- **If you forget:** LP creation fails, you manually send ETH

**Order matters:**
1. ✅ Deploy contracts
2. ✅ Set payout address ← DO THIS
3. ✅ Configure OpenSea drop
4. ✅ Announce mint
5. ✅ Users mint (ETH goes to contract) ✅

**Wrong order:**
1. ✅ Deploy contracts  
2. ❌ Skip payout address
3. ✅ Configure OpenSea drop
4. ✅ Announce mint
5. ❌ Users mint (ETH goes to YOUR wallet) ❌
6. ❌ No ETH in contract for LP ❌

---

### Permanent Liquidity Lock

**CRITICAL: The LP position is locked FOREVER**
- ✅ You can collect trading fees
- ✅ Position cannot be withdrawn
- ✅ Liquidity cannot be removed
- ✅ Position cannot be transferred
- ✅ This is BY DESIGN (prevents rug pulls)

**Emergency functions can ONLY recover:**
- Stuck/loose funds (if LP creation failed)
- Collected fees
- **NOT the locked LP itself**

---

### Minimum Funding Requirements

**TESTED AND CONFIRMED:**
- ✅ **0.1 ETH**: Works perfectly (0.05 ETH to LP)
- ⚠️ **0.08 ETH**: May cause "Price slippage check" errors
- ❌ **< 0.08 ETH**: Likely to fail

**Recommendation:**
- Testing: Use 0.1 ETH minimum
- Production: Fund with expected mint revenue

---

### Dynamic Price Calculation

The LP is created with dynamic price based on:
```
Price = (ETH amount) / (Token amount)

Example with 0.05 ETH:
- LP receives: 0.05 ETH + 16,665 tokens
- Initial price: ~333,000 tokens per ETH
- Price will adjust with trading
```

**This ensures:**
- No hardcoded price (adapts to any funding amount)
- Correct initialization on Uniswap V3
- Minimal slippage on first trades

---

### Gas Costs (Approximate)

```
Deployment: ~$10-20
Configuration: ~$2-5
Creating LP: ~$5-10
Withdrawing operational funds: ~$1-2
Collecting fees (all 3 steps): ~$2-3
  - collectLPFees(): ~$0.50-1
  - withdrawLPFeesWETH(): ~$0.50-1
  - withdrawLPFeesTokens(): ~$0.50-1
Emergency recovery: ~$1-2
Converting WETH to ETH: ~$0.50-1

Total for full launch: ~$20-45
Fee collection per month: ~$2-3

IMPORTANT: Only collect fees when fees > 5-10x gas costs!
Don't spend $3 to collect $0.50 in fees.
```

**Varies with Base gas prices and L1 data costs.**

---

### Rate Limits

**Base has rate limits on rapid transactions:**
- ~10-15 transactions per minute
- Deployment script sends ~13 transactions
- May hit limits occasionally

**Solution:** Wait 5-10 minutes and retry

---

## 🔧 Troubleshooting

### "Price slippage check" Error

**Cause:** Usually insufficient ETH to LP (< 0.05 ETH)

**Solution:**
```bash
# Add more ETH to NFT contract
cast send $NFT \
  --value 0.05ether \
  --private-key $PRIVATE_KEY \
  --rpc-url base

# Retry createLP
```

---

### "No ETH in contract" Error

**Cause:** Forgot to set SeaDrop payout address to NFT contract BEFORE minting started

**What happened:**
- Mint payments went to your wallet instead of NFT contract
- NFT contract has no ETH to create LP

**Solution:**
```bash
# Check NFT contract balance
cast balance $NFT --rpc-url base
# If it's 0 or very low, you need to manually send ETH

# Send ETH to NFT contract (use expected total from mint)
cast send $NFT \
  --value 22.2ether \
  --private-key $PRIVATE_KEY \
  --rpc-url base

# For testing, use 0.1 ETH minimum
cast send $NFT \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

**Prevention:**
- ✅ ALWAYS set payout address in Step 4 BEFORE announcing mint
- ✅ Test on testnet first to verify payout flows correctly

---

### "Mint not completed yet" Error

**Cause:** Forgot to call `setMintCompleted()`

**Solution:**
```bash
cast send $NFT \
  'setMintCompleted()' \
  --private-key $PRIVATE_KEY \
  --rpc-url base
```

---

### "LP creation delay not passed" Error

**Cause:** Trying to call `createLP()` before 5-minute delay

**Solution:** Wait 5 minutes OR use `createLPImmediate()` instead

---

### "LP already created" Error

**Cause:** LP was already successfully created

**Check status:**
```bash
cast call $LP_MANAGER "lpCreated()" --rpc-url base
# If returns 0x01, LP is created
```

---

### Pool Not Showing on Uniswap

**Cause:** Uniswap's indexer needs time

**Solution:** Wait 10-15 minutes, then refresh

**Verify pool exists on-chain:**
```bash
# Check pool address
cast call $LP_MANAGER "getExpectedLPPair()" --rpc-url base

# Verify liquidity in pool
cast call 0x4200000000000000000000000000000000000006 \
  "balanceOf(address)" \
  YOUR_POOL_ADDRESS \
  --rpc-url base
```

---

### Rate Limit Errors

**Cause:** Too many transactions too quickly

**Solution:** Wait 5-10 minutes, then retry

**Full error message:**
```
error code -32000: in-flight transaction limit reached
```

---

## 📊 Testing Checklist

Before production launch, test everything on Base Sepolia testnet:

### Deployment Testing
- [ ] Deploy all 3 contracts to Sepolia
- [ ] Verify all contracts on BaseScan Sepolia
- [ ] Save all contract addresses

### Configuration Testing
- [ ] Set SeaDrop payout address to NFT contract
- [ ] Fund NFT contract with 0.1 test ETH
- [ ] Verify contract balance is correct

### LP Creation Testing
- [ ] Call `setMintCompleted()`
- [ ] Wait 5 minutes (or use createLPImmediate)
- [ ] Call `createLP()` successfully
- [ ] Verify LP created (lpCreated returns true)
- [ ] Verify trading is enabled
- [ ] Verify pool has liquidity (check WETH and token balances)
- [ ] Find pool on Uniswap (wait 10-15 min for indexing)

### Trading Testing
- [ ] Do test buy (ETH → tokens on Uniswap)
- [ ] Do test sell (tokens → ETH on Uniswap)
- [ ] Verify both directions work
- [ ] Verify pool handles trades correctly

### Fee Collection Testing
- [ ] Check uncollected fees (via Uniswap or positions() call)
- [ ] Collect fees: `collectLPFees()`
- [ ] Withdraw WETH fees: `withdrawLPFeesWETH()`
- [ ] Verify WETH balance increased
- [ ] Withdraw token fees: `withdrawLPFeesTokens()`
- [ ] Verify token balance increased
- [ ] Verify LP Manager is empty after withdrawal

### Emergency Recovery Testing
- [ ] Send test ETH to LP Manager
- [ ] Recover it with `recoverLPManagerETH()`
- [ ] Verify ETH recovered to wallet
- [ ] Send test tokens to LP Manager
- [ ] Recover them with `recoverLPManagerTokens()`
- [ ] Verify tokens recovered to wallet

### Operational Testing
- [ ] Withdraw operational funds successfully
- [ ] Verify operational funds received

### Position Verification
- [ ] Check position details via positions() call
- [ ] Verify position NFT owned by LP Manager
- [ ] Verify liquidity is locked (can't be withdrawn)
- [ ] Verify position on Uniswap interface

**✅ Only deploy to mainnet after ALL tests pass!**

---

## 📈 Production Launch Checklist

- [ ] Update Deploy.s.sol with production values
- [ ] Deploy to Base mainnet
- [ ] Save all contract addresses
- [ ] Verify all contracts on BaseScan
- [ ] **🚨 CRITICAL: Configure SeaDrop payout address** (Step 4)
- [ ] Fund NFT contract (use expected mint revenue OR 0.1 ETH for testing)
- [ ] Configure drop in OpenSea Studio
- [ ] **Double-check payout address is set before announcing!**
- [ ] Announce drop to community
- [ ] Monitor mint progress
- [ ] When sold out, call `setMintCompleted()`
- [ ] Wait 5 minutes, then `createLP()`
- [ ] Verify LP creation successful
- [ ] Withdraw operational funds
- [ ] Announce trading is live
- [ ] Monitor pool activity
- [ ] Set fee collection schedule

---

## 🔗 Important Links

### Base Network
- **Mainnet RPC:** https://mainnet.base.org
- **BaseScan:** https://basescan.org
- **Chain ID:** 8453

### Uniswap V3 on Base
- **Position Manager:** 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
- **Factory:** 0x33128a8fC17869897dcE68Ed026d694621f6FDfD
- **Router:** 0x2626664c2603336E57B271c5C0b26F421741e481
- **WETH:** 0x4200000000000000000000000000000000000006

### SeaDrop
- **Contract:** 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5
- **OpenSea Studio:** https://opensea.io/studio

---

## 💡 Tips for Success

1. **Set Payout Address FIRST:** Do Step 4 before ANY mints happen!
2. **Test Everything:** Deploy to Sepolia testnet first
3. **Use Enough ETH:** 0.1 ETH minimum for testing
4. **Save Addresses:** Keep contract addresses in multiple places
5. **Monitor Closely:** Watch mint progress and LP creation
6. **Communicate:** Keep community updated on launch progress
7. **Be Patient:** Uniswap indexing takes 10-15 minutes
8. **Collect Fees Regularly:** Don't let fees accumulate too long
9. **Document Everything:** Keep notes on what you did
10. **Double-Check Payout:** Verify payout address is set before announcing mint!

---

## 🎓 Key Learnings

**What Makes This System Work:**

1. **Dynamic Price Calculation:** Adapts to any ETH amount sent - no hardcoded prices
2. **Minimum 0.05 ETH to LP:** Prevents edge cases in price/slippage calculations
3. **Full-Range Position:** Simple, always active liquidity - no tick management needed
4. **Permanent Lock:** Shows commitment, prevents rug pulls, builds trust
5. **Owner Fee Collection:** You control when to collect, no governance needed
6. **Emergency Recovery:** Safety net if something goes wrong during deployment
7. **3-Step Fee Process:** Collect → Withdraw WETH → Withdraw Tokens (simple and predictable)
8. **100% Fee Ownership:** As sole LP, you get all trading fees forever

**Critical Success Factors:**
- ✅ Set payout address BEFORE any mints
- ✅ Use 0.1 ETH minimum for LP creation
- ✅ Verify each step before proceeding
- ✅ Collect fees regularly (when > gas costs)
- ✅ Monitor pool health and trading volume
- ✅ Keep good records of earnings
- ✅ Understand WETH vs ETH distinction
- ✅ Test everything on testnet first

---

## 📞 Support

If you encounter issues:

1. **Check Troubleshooting Section:** Most common issues are documented with solutions
2. **Verify Addresses:** Ensure contract addresses are saved and correct
3. **Check Transaction Status:** View on BaseScan to see if transactions succeeded
4. **Verify Funding:** Ensure you're using 0.1+ ETH for LP creation
5. **Wait for Rate Limits:** If hitting rate limits, wait 5-10 minutes
6. **Check Fee Collection:** Use Quick Reference commands to verify each step
7. **View Position on Uniswap:** Confirm pool and fees visually
8. **Test on Sepolia First:** Always test major operations on testnet

**Common Issues Quick Links:**
- Payout address not set → See Step 4 in Deployment
- Price slippage error → See Troubleshooting
- Fee collection failing → See Fee Collection Common Mistakes
- Pool not on Uniswap → Wait 10-15 minutes for indexing

---

## ⚖️ License

MIT License - Use freely, deploy responsibly

---

## 📖 Quick Reference

### Essential Commands Cheat Sheet

**Check LP Status:**
```bash
cast call $LP_MANAGER "lpCreated()" --rpc-url base
cast call $LP_MANAGER "positionTokenId()" --rpc-url base
cast call $LP_MANAGER "getExpectedLPPair()" --rpc-url base
```

**Check Balances:**
```bash
cast balance $NFT --rpc-url base                           # NFT contract ETH
cast call $TOKEN "balanceOf(address)" YOUR_WALLET --rpc-url base  # Your tokens
cast call 0x4200000000000000000000000000000000000006 "balanceOf(address)" YOUR_WALLET --rpc-url base  # Your WETH
```

**Collect Fees (3 steps):**
```bash
cast send $NFT 'collectLPFees()' --private-key $PK --rpc-url base
cast send $NFT 'withdrawLPFeesWETH()' --private-key $PK --rpc-url base
cast send $NFT 'withdrawLPFeesTokens()' --private-key $PK --rpc-url base
```

**Check Uncollected Fees:**
```bash
cast call 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1 \
  "positions(uint256)" \
  $(cast call $LP_MANAGER "positionTokenId()" --rpc-url base) \
  --rpc-url base
# Look at fields 10 and 11 for uncollected fees
```

**Withdraw Operational Funds:**
```bash
cast send $NFT 'withdrawOperationalFunds()' --private-key $PK --rpc-url base
```

**Emergency Recovery:**
```bash
cast send $NFT 'recoverLPManagerETH()' --private-key $PK --rpc-url base
cast send $NFT 'recoverLPManagerTokens(address)' $TOKEN --private-key $PK --rpc-url base
```

---

## 🎉 Congratulations!

You now have a complete, production-ready NFT-to-token system with permanent Uniswap V3 liquidity!

**Built with:**
- ✅ Automatic token distribution
- ✅ Permanent liquidity lock
- ✅ Owner-controlled fee collection
- ✅ Emergency recovery functions
- ✅ Dynamic price calculation
- ✅ Thoroughly tested

**Deploy with confidence!** 🚀

---

*Last Updated: November 2025*
*Tested on Base Mainnet*
*System Version: 1.0*

**Version History:**
- v1.0 (Nov 2025): Initial release with comprehensive LP verification and fee collection guide
- Includes: Full deployment workflow, fee collection testing, troubleshooting, and best practices
- Tested with: 0.05 ETH LP, dynamic pricing, 3-step fee collection process
