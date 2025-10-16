# 🌀 KhoopDefi Smart Contract

## Overview
KhoopDefi is a decentralized smart contract system designed to distribute rewards through a strict FIFO (First-In-First-Out) queue. Users purchase entries that progress through a series of cycles, earning payouts at each stage. The system enforces fairness, transparency, and automation using a Hybrid Strict Cycle Model.

## 🔁 Cycle Processing Logic
KhoopDefi uses a Hybrid Strict FIFO Cycle Model to ensure fair and efficient distribution of cycle payouts.

### 🔹 How It Works
- Each active entry receives only one cycle per round
- Entries are processed in strict queue order
- After a full loop:
  - If any cycles were processed, the system automatically continues
  - If no cycles were processed (e.g., all entries are maxed out), the loop breaks
- The contract continues processing as long as:
  - `balance >= CYCLE_PAYOUT`
  - There are eligible entries (`isActive == true` and `cyclesCompleted < MAX_CYCLES_PER_ENTRY`)

### 🔹 Entry Lifecycle
- Each entry can receive up to `MAX_CYCLES_PER_ENTRY` (default: 4)
- Once maxed out, the entry is marked inactive and skipped in future rounds

## ⚠️ Entry Timing & Fairness
If it appears that User 1's entries cycle faster, this is expected behavior under FIFO:
- User 1 entered first, so their entries are at the front of the queue
- The system processes entries in order, one cycle per round
- As long as balance is available, the system loops and continues paying cycles
- New users are added to the queue and picked up in the next round

### ✅ This ensures:
- No entry is skipped
- No entry receives more than one cycle per round
- All users progress fairly based on queue position

## 🧮 Cycle Completion Math
### Assuming:
- 10 entries per user
- 4 users total
- Each entry needs 4 cycles
- Each cycle costs 5 USDT

### Hybrid Model (Auto-Looping)
- User 1 completes all 40 cycles in 4 rounds
- System loops automatically
- No manual trigger needed

### Strict Queue Model (Manual Trigger)
- Each round processes 1 cycle per entry
- Requires 4 separate calls to continue
- All users progress evenly
- Balance may sit idle between rounds

| Model | Auto-Loop | Manual Trigger | User 1 Speed | Total Cost |
|-------|-----------|----------------|---------------|------------|
| Hybrid (default) | ✅ | ❌ | Fastest | 200 USDT |
| Strict (manual) | ❌ | ✅ | Even pacing | 200 USDT |

## 🧪 Test Scenario: 4 Users Buying 10 Entries Each
To validate the system, we ran a test where four users each purchased 10 entries, one after the other.

### 🔹 Setup
- **Users**: user, test1, test2, test3
- Each user called `purchaseEntries(10)`
- The contract processed cycles using the hybrid strict FIFO model

### 🔹 Results
| User | Total Entries | Total Cycles Completed | Active Entries Remaining |
|------|---------------|------------------------|--------------------------|
| user | 10 | 26 | 0 |
| test1 | 10 | 12 | 6 |
| test2 | 10 | 10 | 10 |
| test3 | 10 | 10 | 10 |

✅ **User 1's entries were processed first** due to queue position  
✅ Each entry received **one cycle per round**  
✅ New users were picked up in subsequent rounds  
✅ No entries were skipped  

### 🔹 Entry-Level Check
We verified that even the last entry of test1 (entry ID 20) received at least one cycle this was checked immediately after buying 10 slots with test1 meaning the next payout his last slot #20 also received payout as you can see the details below:ng: 3
```

```
### 🔹 Contract Balance Behavior
- Contract balance before user purchase: 0
- Contract balance after each user purchase: 0

✅ All funds were distributed immediately via:
- Cycle payouts
- Referral bonuses
- Team shares

## 📊 Global Stats After Test
| Metric | Value |
|--------|-------|
| Total users | 5 |
| Total active users | 5 |
| Total entries purchased | 40 |
| Total referrer bonus paid | 40 USDT |
| Total payouts made | 520 USDT |
| Total cycles completed | 104 |
| Total team earnings | 40 USDT |

✅ These stats confirm that the system is functioning as expected, with accurate tracking of user activity, payouts, and team allocations.

## Manual Trigger
The manual cycle function is still available for processing all withdrawal multisig functions are deprecated

```solidity
function completeCycle() external {
    _processAvailableCycles();
}
```

## 📌 Summary
KhoopDefi's cycle system is:
- ✅ **Fair**: strict FIFO, one cycle per round
- ✅ **Efficient**: auto-looping with no idle balance
- ✅ **Scalable**: handles multiple users and entries seamlessly
- ✅ **Transparent**: logs and tests confirm correct behavior
```