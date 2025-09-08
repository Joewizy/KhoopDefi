# Khoop DeFi - Automated Slot-Based Investment Platform

## Overview
Decentralized investment platform using automated slot-based system. Users buy entries, join a queue, and receive guaranteed payouts.

## 🎯 Core Mechanics
- **Entry Cost**: $15 USDT per slot
- **Total Payout**: $20 USDT per completed slot  
- **Profit**: $5 USDT (33.33% ROI)

### Revenue Distribution ($15 USDT)
- **$11** → Queue Payouts (73.33%)
- **$3** → Buyback System (20%)
- **$1** → Team Operations (6.67%)

## 🔄 How It Works

### 1. Entry Purchase
- Pay $15 USDT to buy slot
- Get unique entry ID and queue position
- Entry marked as "pending" until completion

### 2. Automatic Buyback System
- **Accumulation**: $3 per entry goes to buyback pool
- **Trigger**: When pool reaches $10 USDT threshold
- **Action**: Automatically completes oldest pending entry
- **Frequency**: Every ~4 entries

### 3. Cycle Completion
- **Capital Return**: $15 USDT (original investment)
- **Profit Payment**: $5 USDT (guaranteed profit)
- **Total Received**: $20 USDT

### 4. Referral System
- **Bonus**: $1 USDT per referred entry
- **Payment**: Immediate when referral purchases
- **No Limits**: Unlimited referral potential

## 🏗️ Technical Features

### Security
- **Daily Limits**: Max 50 entries per user per day
- **Transaction Limits**: Max 10 entries per transaction
- **Anti-Spam**: 10-minute minimum between purchases
- **Reentrancy Protection**: SafeERC20 and ReentrancyGuard

### Gas Optimization
- **Pending Start ID**: O(1) queue pointer instead of O(n) scanning
- **Batch Operations**: Multiple entries in single transaction

## 🚀 Getting Started

### Prerequisites
- USDT-compatible wallet (MetaMask, Trust Wallet)
- Minimum $15 USDT balance
- Referrer address (existing user)

### Process
1. Connect wallet to dApp
2. Get referrer address from existing user
3. Purchase entry: Send $15 USDT
4. Track progress and wait for payout
5. Refer others to earn bonuses

## 🔧 Key Functions
- `purchaseEntries(amount, numEntries, referrer)`: Buy slots
- `completeCycle(entryId)`: Manual cycle completion
- `getGlobalStats()`: System-wide statistics
- `getUserPendingEntries(user)`: User's pending slots

## ⚠️ Risk Considerations
- **Smart Contract Risk**: Code vulnerabilities
- **Market Dependency**: Requires continuous growth
- **Regulatory Risk**: Potential legal changes

**⚡ Built with Solidity, secured by blockchain, powered by community growth.**
