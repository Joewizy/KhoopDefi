# Khoop DeFi - Automated Slot-Based Investment Platform

## Overview
Decentralized investment platform using an automated, cycle-based system. Users purchase entries, complete cycles, and earn guaranteed payouts with a clear 4-cycle limit per entry.

## 🎯 Core Mechanics
- **Entry Cost**: $15 USDT per entry
- **Cycles per Entry**: Maximum of 4 cycles
- **Payout per Cycle**: $5 USDT
- **Total Potential per Entry**: $20 USDT
- **Profit per Entry**: $5 USDT (33.33% ROI)

### Revenue Distribution ($15 USDT)
- **$11** → Cycle Payouts (73.33%)
- **$3** → Buyback System (20%)
- **$1** → Team Operations (6.67%)

## 🔄 How It Works

### 1. Entry Purchase
- Pay $15 USDT to buy 1-20 entries per transaction
- 30-minute cooldown between purchases (can be reduced to 15 min for $0.50 fee)
- Each entry gets a unique ID and joins the queue

### 2. Cycle System
- Each entry can complete up to 4 cycles
- Each cycle pays out $5 USDT
- After 4 cycles, entry becomes inactive
- Users must purchase new entries to continue earning

### 3. Automatic Buyback System
- **Accumulation**: $3 per entry goes to buyback pool
- **Trigger**: When pool reaches $10 USDT threshold
- **Action**: Automatically completes cycle for oldest active entry
- **Max Cycles**: 4 cycles per entry

### 4. Queue & Transparency
- View next entry in line using `getNextInLine()`
- Track your active entries with `getUserActiveEntries()`
- Monitor global stats including total cycles completed

### 5. Referral System
- Earn $1 USDT for each new user you refer
- One-time bonus per referred user

## 🛠 Key Functions

### For Users
- `purchaseEntries(uint256 numEntries, address referrer)` - Buy new entries
- `reduceCooldown()` - Pay $0.50 to reduce cooldown to reduce 15mins from their cooldown
- `getNextInLine()` - View next entry due for payment

### View Functions
- `getUserActiveEntries(address user)` - List all active entries
- `getEntryDetails(uint256 entryId)` - View entry details
- `getUserPotentialEarnings(address user)` - Calculate potential earnings
- `getCooldownRemaining(address user)` - Check remaining cooldown

## ⚙️ Technical Details
- Built on Ethereum with Solidity 0.8.30
- Uses OpenZeppelin contracts for security
- Implements reentrancy protection
- Gas optimized for efficient transactions

## 🔒 Security
- Comprehensive test coverage