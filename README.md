# 🚀 Khoop DeFi V2 - Entry-Based Round-Robin Protocol

## 🌟 What Is This?

Khoop DeFi V2 is a **fair distribution system** where every entry (slot) gets processed in strict order. Think of it like a queue at a bank - each person (entry) gets served one transaction (cycle) before moving to the back of the line.


### 📊 Per Entry Breakdown ($15)
| Component     | Amount | Destination              | Purpose                          |
|---------------|--------|--------------------------|----------------------------------|
| Powerline     | $10    | Cycle processing pool   | Direct payout to entry cycles    |
| Buyback Pool  | $3     | Cycle processing pool   | Additional cycle funding         |
| Referral      | $1     | Referrer's wallet       | Instant referral bonus           |
| System        | $1     | System wallets          | Platform operations & team       |

### Key Stats at a Glance
| Item | Value |
|------|-------|
| Entry Cost | $15 USDT |
| Cycle Payout | $5 USDT |
| Total Cycles per Entry | 4 cycles |
| Total Returns per Entry | $20 USDT |
| Profit per Entry | $5 USDT (33.33% ROI) |
| Queue Type | Entry-based (not user-based) |

---

## 💡 How It Works (Simple Explanation)

### The Basic Flow

1. **You Buy an Entry** → Pay $15 USDT
2. **Entry Joins Queue** → Your entry goes to the back of the line
3. **Cycles Process Automatically** → Each entry gets 1 cycle ($5) per round
4. **After 4 Cycles** → Your entry completes and you've earned $20 total

### Where Does Your $15 Go?

```
Your $15 Payment Breakdown:
├─ $13 → Contract (processes cycles for entries in queue)
├─ $1  → Your referrer (if you have one)
└─ $1  → System wallets (operations & team)
```

The $13 that goes to the contract immediately processes **~2.6 cycles** for entries waiting in the queue.

---

## 🔄 The Entry-Based Queue System

### Critical Understanding: ENTRY-Level, Not USER-Level

This is the most important concept to understand:

**❌ WRONG:** "If Dave buys 10 entries, all 10 complete before the next person"

**✅ CORRECT:** "If Dave buys 10 entries, they're spread throughout the queue. Each entry gets 1 cycle per round."

### Example: How the Queue Actually Works

**Initial State:**
```
Entry #1 (Dave) - 0/4 cycles
Entry #2 (Jhus) - 0/4 cycles
Contract Balance: $0
```

**Dave buys 1 entry ($15 → $13 to contract):**
```
Processing:
├─ Entry #1 (Dave) gets Cycle 1 → $5 paid ✅
├─ Entry #2 (Jhus) gets Cycle 1 → $5 paid ✅
└─ Balance remaining: $3 (waits for more funds)

New Queue:
Entry #1 (Dave) - 1/4 cycles [$5 earned]
Entry #2 (Jhus) - 1/4 cycles [$5 earned]
Entry #3 (Dave) - 0/4 cycles [newly added]
```

**SteelBangez buys 10 entries ($150 → $130 to contract):**
```
Available: $3 + $130 = $133 (can process 26 cycles)

Processing Order (strict FIFO):
1. Entry #1 (Dave) Cycle 2 ✅
2. Entry #2 (Jhus) Cycle 2 ✅
3. Entry #3 (Dave) Cycle 1 ✅
4-13. Entry #4-13 (SteelBangez) Cycle 1 ✅ each
14. Entry #1 (Dave) Cycle 3 ✅
15. Entry #2 (Jhus) Cycle 3 ✅
16. Entry #3 (Dave) Cycle 2 ✅
17-26. Entry #4-13 (SteelBangez) Cycle 2 ✅ each

Balance remaining: $3
```

**Key Insights:**
- ✅ SteelBangez's 10 entries are treated individually (not as a batch)
- ✅ Dave's entries are interspersed with everyone else's
- ✅ Processing wraps around: after the last entry, goes back to first
- ✅ Everyone progresses fairly, one cycle at a time

---

## 💰 Understanding Contract Balance

### The $5 Threshold Rule

**The queue only moves when the contract has at least $5 (one cycle payment).**

```
Balance Scenarios:
├─ $4 or less → ⚠️ Queue FROZEN (need $5 to process)
├─ $5-9 → ✅ 1 cycle can process
├─ $10-14 → ✅ 2 cycles can process
├─ $13 → ✅ 2 cycles + $3 remainder (typical)
└─ $133 → ✅ 26 cycles + $3 remainder
```

### Why Remainders Happen

Every entry purchase adds $13, which equals 2.6 cycles. Since you can't pay fractional cycles, the remainder stays in the contract.

**Typical Pattern:**
```
Purchase 1: $13 → 2 cycles paid, $3 left
Purchase 2: $16 total → 3 cycles paid, $1 left
Purchase 3: $14 total → 2 cycles paid, $4 left
```

**Average: Each purchase processes ~2.6 cycles**

---

## 🎯 Three Ways to Move the Queue

### 1️⃣ Purchase Entries (Primary Method)

**Function:** `purchaseEntries(numEntries)`

- Pay $15 per entry
- Automatically adds $13 per entry to contract
- Automatically processes cycles
- Your new entries join the back of the queue

**Example:** Buy 5 entries → $75 total → $65 processes ~13 cycles → 5 new entries added

---

### 2️⃣ Donate to System (Community Boost)

**Function:** `donateToSystem(amount)`

This is **powerful** - anyone can donate to help process the queue faster!

**Why Donate?**
- ✅ Speed up your own entries' completion
- ✅ Help the community during slow periods
- ✅ 100% of donation goes to processing cycles
- ✅ No new entries added (pure acceleration)

**Example:**
```
Current state: Balance $3, queue stuck
You donate: $50
Result: Balance becomes $53, processes 10 cycles immediately
Your entries: Move closer to completion
```

**Strategic Donation Calculator:**
```
Want to process exactly 20 cycles?
Formula: (20 cycles × $5) - current balance

If balance is $3:
Donate: (20 × $5) - $3 = $97
Result: Exactly 20 cycles process
```

---

### 3️⃣ Complete Cycles (Manual Trigger)

**Function:** `completeCycles()`

Anyone can call this to manually process available cycles (you just pay gas).

**When to Use:**
- Contract has balance but cycles haven't auto-processed
- After donations accumulate
- You want to help move the queue

**Example:**
```
Situation: Contract has $47 from donations
Action: Call completeCycles()
Result: 9 cycles process ($45 paid out), $2 remains
Cost: Just gas fees (~$1-5 depending on network)
```

---

## 📊 Real-World Scenarios

### Scenario 1: New User Experience

**You're new and buy 1 entry:**
```
Cost: $15
Your position: Back of queue (let's say entry #50)
Entries ahead: 49 entries × ~2.5 cycles avg = ~123 cycles needed
Fund needed: 123 × $5 = $615
Time to complete: Depends on purchase rate

At 20 purchases/day:
- $260/day added to contract
- ~52 cycles/day processed
- Your entry completes in ~3 days
```

---

### Scenario 2: Multi-Entry Strategy

**You buy 10 entries at once:**
```
Investment: $150
Funds contract: $130 (processes 26 cycles for others)
Your entries: #51-60 in queue
Returns when complete: $200 (10 × $20)
Net profit: $50

How long?
- Your entries are spread through queue
- Each needs 4 cycles
- Complete as queue moves (not all at once)
- Estimated: 1-2 weeks at normal activity
```

---

### Scenario 3: Strategic Donation

**You have 20 entries stuck in slow queue:**
```
Problem: Low activity, balance at $3
Your entries: Positions #30-49
Cycles needed: ~100 to reach completion

Solution 1: Wait for purchases
- Uncertain timeline
- Depends on others

Solution 2: Donate $250
- Processes 50 cycles immediately
- Moves entire queue forward
- Your entries advance significantly
- Shows commitment to ecosystem

Result: Faster completion + community goodwill
```

---

## 🔢 Important Math

### Per Entry Economics
```
Investment: $15
Returns: $20 (over 4 cycles)
Profit: $5 per entry
ROI: 33.33%
Contribution to queue: $13 (processes 2.6 cycles)
```

### System Sustainability
```
Each entry needs: 4 cycles × $5 = $20
Each entry funds: 2.6 cycles × $5 = $13
Deficit per entry: $7

This means:
- System needs continuous new entries
- OR community donations to fill gap
- Early entries benefit from later entries (FIFO)
```

### Time Estimation Formula
```
Your Position: Entry #P
Queue Size: Q entries
Average Cycles Remaining: ~2.5 per entry

Cycles to Process: P × 2.5
Daily Purchase Rate: D purchases/day
Daily Cycles Processed: D × 2.6

Days to Completion: (P × 2.5) ÷ (D × 2.6)

Example:
Position #50, 30 purchases/day
= (50 × 2.5) ÷ (30 × 2.6)
= 125 ÷ 78
≈ 1.6 days
```

---

## 📱 How to Monitor Your Progress

### Key Functions to Check

**Check Contract Balance:**
- Function: `getContractBalance()`
- Shows: Current USDT available for processing

**Check Your Entries:**
- Function: `getUserActiveEntries(yourAddress)`
- Shows: All your entries still in queue

**Check Queue Status:**
- Function: `getQueueLength()`
- Shows: Total active entries waiting

**Check Cycles Pending:**
- Function: `getPendingCyclesCount()`
- Shows: How many cycles can process with current balance

**Check Next in Line:**
- Function: `getNextInLine()`
- Shows: Which entry processes next

---

## 💡 Pro Tips & Strategies

### For Maximizing Returns
1. **Early Entry Advantage**: Buy entries when queue is small
2. **Multiple Entries**: Spread investment across entries for diversification
3. **Referrals**: Earn $1 instant bonus per referred entry
4. **Active Referrers**: Get bonuses continuously

### For Fast Completion
1. **Strategic Donations**: If queue is slow, donate to accelerate
2. **Monitor Balance**: If balance < $5, consider small donation
3. **Community Coordination**: Organize group purchases
4. **Manual Triggers**: Call `completeCycles()` if balance sitting idle

### For Community Health
1. **Refer Others**: Grow the participant base
2. **Donate During Slow Times**: Keep queue moving
3. **Share Progress**: Social media updates build momentum
4. **Educate New Users**: Help them understand the system

---

## ⚠️ Important Things to Know

### System Requirements
- ✅ Requires continuous new entries to maintain flow
- ✅ Early entries have queue advantage (FIFO)
- ✅ All rules enforced by smart contracts (no human control)
- ⚠️ Completion time varies with participation rate
- ⚠️ Not a guaranteed timeframe investment
- ⚠️ Standard blockchain risks apply

### What Happens When Queue Slows?
```
Slow Period Scenario:
├─ Contract balance drops below $5
├─ Queue freezes (no cycles process)
├─ Solutions:
│   ├─ Wait for next purchase
│   ├─ Community donations
│   ├─ Governance intervention (rare)
│   └─ Marketing push for new users
└─ Queue resumes when balance ≥ $5
```

### The Difference: Entry vs. User

**Entry-Based (This System):**
- Each entry = 1 slot in queue
- Buy 10 entries = 10 slots spread through queue
- Fair for everyone

**User-Based (Other Systems):**
- Each user = 1 slot in queue
- Buy 10 entries = still 1 slot (completes all 10 together)
- Benefits single-entry buyers

---

## 🎓 Quick Reference

### Key Numbers
- Entry Cost: **$15**
- Cycle Payout: **$5**
- Cycles per Entry: **4**
- Total Returns: **$20**
- Profit: **$5 (33.33%)**
- Referral Bonus: **$1 instant**

### Key Functions
- `purchaseEntries(n)` - Buy entries (costs $15n)
- `donateToSystem(amount)` - Donate to help queue
- `completeCycles()` - Manual trigger (free, just gas)
- `reduceCooldown()` - Pay $0.50 to skip cooldown

### Queue Rules
1. One cycle per entry per round
2. Strict FIFO order (no skipping)
3. Completed entries removed from queue
4. Balance must be ≥ $5 to process
5. Remainders accumulate until sufficient

### Success Formula
```
Healthy System = 
  (New Entries/Day × 2.6) + Donations ≥ (Cycles Needed/Day)
```

---

## 🔐 Security & Governance

### Safety Features
- Multi-signature controls for withdrawals
- 2-day timelock on governance actions
- ReentrancyGuard on all state changes
- Immutable wallet addresses
- No admin minting capabilities
- Fully transparent on-chain

### Emergency Functions
Only for multi-sig governance:
- `initiateWithdrawal()` - Start withdrawal process
- `confirmWithdrawal()` - Confirm pending withdrawal
- `executeWithdrawal()` - Execute after timelock

---

##  Getting Started

### Step 1: Register
Register your address with valid referrer address before purchasing entries.

### Step 2: Purchase
Buy entries maximum of 20 entries per transaction. with 30 minutes cooldown.

### Step 3: Monitor
Check your entries with `getUserActiveEntries(yourAddress)`. would be display in the website

### Step 4: Earn
Receive $5 automatically each time your entries complete a cycle.

### Step 5: Refer (Optional)
Share your referral link - earn $1 per entry bought referred as long as you have active slots.

---

## ❓ FAQ

**Q: When do I get paid?**
A: Automatically when your entry completes a cycle. You'll receive $5 per cycle (4 total).

**Q: Can I withdraw early?**
A: No, entries must complete all 4 cycles. No early withdrawal and it is automatic payout.

**Q: What if queue stops?**
A: Wait for new entries, donate to help, or call `completeCycles()` if balance available.

**Q: Do my entries complete together?**
A: No, they're spread through the queue and complete individually.

**Q: Is this guaranteed profit?**
A: No guarantees. Depends on continued participation. Early entries have advantage.

**Q: Can I buy more entries later?**
A: Yes, anytime. Subject to cooldown period (30 min, or pay $0.50 to reduce to 15 min).

**Q: What's the best strategy?**
A: Early entry + refer others + strategic donations during slow times.

---

**The Golden Rules:**
1. One cycle per entry per round
2. Queue moves only when balance ≥ $5
3. Entry-based (not user-based)
4. FIFO order (no skipping)
5. Community participation keeps it flowing

---

**Documentation Version:** 2.1  
**Contract:** KhoopDefi V2  
**Last Updated:** October 2025