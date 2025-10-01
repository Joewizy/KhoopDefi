// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Khoop-Defi
 * @notice Sustainable slot-based system with 4-cycle cap and automated payouts
 * @dev Entry: $15, Max earnings: $20 (4 cycles × $5), Repurchase required after maxing out
 */
contract KhoopDefi is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error KhoopDefi__ExceedsTransactionLimit();
    error KhoopDefi__InsufficientBalance();
    error KhoopDefi__InvalidReferrer();
    error KhoopDefi__CycleNotComplete();
    error KhoopDefi__ZeroAddress();
    error KhoopDefi__InCooldown();
    error KhoopDefi__MustPayExactAmount();
    error KhoopDefi__OnlyEntryOwner();
    error KhoopDefi__EntryMaxedOut();
    error KhoopDefi__CooldownNotActive();
    error KhoopDefi__CooldownAlreadyReduced();
    error KhoopDefi__InsufficientCooldownTime();

    // ============ Types ============
    struct User {
        address referrer;
        uint256 totalEntriesPurchased;
        uint256 totalCyclesCompleted;
        uint256 referrerBonusEarned;
        uint256 totalEarnings;
        uint256 totalReferrals;
        uint256 cooldownEnd; // For cooldown tracking
        bool isRegistered;
    }

    struct Entry {
        uint256 entryId;
        address owner;
        uint256 purchaseTimestamp;
        uint8 cyclesCompleted; // Max 4 cycles
        uint256 lastCycleTimestamp;
        bool isActive; // false when 4 cycles are done
    }

    struct GlobalStats {
        uint256 totalUsers;
        uint256 totalEntriesPurchased;
        uint256 totalReferrerBonusPaid;
        uint256 totalPayoutsMade;
        uint256 totalCyclesCompleted;
    }

    // ============ Constants ============
    uint256 private constant CORE_TEAM_SHARE = 15e16; // $0.15 each (4 wallets)
    uint256 private constant INVESTORS_SHARE = 2e16; // $0.02 each (15 wallets)
    uint256 private constant CONTINGENCY_SHARE = 1e17; // $0.10
    uint256 private constant ENTRY_COST = 15e18; // $15 entry cost
    uint256 private constant CYCLE_PAYOUT = 5e18; // $5 per cycle
    uint256 private constant MAX_CYCLES_PER_ENTRY = 4; // 4 cycles max ($20 total)
    uint256 private constant MAX_ENTRIES_PER_TX = 20; // 1-20 entries per purchase
    uint256 private constant REFERRER_WELCOME_BONUS = 1e18; // $1 one-time bonus
    uint256 private constant COOLDOWN_PERIOD = 30 minutes; // Standard cooldown
    uint256 private constant REDUCED_COOLDOWN = 15 minutes; // With fee
    uint256 private constant COOLDOWN_FEE = 5e17; // $0.50 fee
    uint256 private constant BUYBACK_PER_ENTRY = 3e18; // $3 per entry
    uint256 private constant BUYBACK_THRESHOLD = 10e18; // $10 threshold
    uint256 private constant MAX_AUTO_FILLS_PER_PURCHASE = 5;

    // ============ State Variables ============
    address[4] public coreTeamWallet;
    address[15] public investorsWallet;
    address public reserveWallet;
    address public buybackWallet;
    address public powerCycleWallet;

    IERC20 public immutable usdt;

    // ============ Mappings ============
    mapping(address => User) public users;
    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;
    mapping(address => bool) public referralBonusPaid;

    // ============ Global Tracking ============
    GlobalStats public globalStats;
    uint256 public nextEntryId = 1;
    uint256 public buybackAccumulated;
    uint256 public pendingStartId = 1; // Queue pointer to next pending entry
    uint256 public distributedTeamShares;

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed referrer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint8 cycleNumber, uint256 payoutAmount);
    event EntryMaxedOut(uint256 indexed entryId, address indexed user);
    event ReferrerBonusPaid(address indexed referrer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed referrer);
    event BatchEntryPurchased(uint256 startId, uint256 endId, address indexed user, uint256 totalCost);
    event CooldownReduced(address indexed user, uint256 feePaid);
    event BuybackAutoFill(uint256 indexed entryId, uint256 amount);
    event TeamSharesDistributed(uint256 totalEntries);
    event MultipleAutoFillsProcessed(uint256 count, uint256 remainingBuyback);

    // ============ Modifiers ============
    modifier validReferrer(address referrer) {
        if (!users[msg.sender].isRegistered) {
            if (referrer == address(0) || referrer == msg.sender) {
                revert KhoopDefi__InvalidReferrer();
            }
            if (!users[referrer].isRegistered) {
                revert KhoopDefi__InvalidReferrer();
            }
        }
        _;
    }

    // ============ Constructor ============
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _buyback,
        address _powerCycle,
        address _usdt
    ) Ownable(msg.sender) {
        if (_reserve == address(0) || _buyback == address(0) || _powerCycle == address(0) || _usdt == address(0)) {
            revert KhoopDefi__ZeroAddress();
        }

        for (uint256 i = 0; i < 4; i++) {
            if (_coreTeam[i] == address(0)) revert KhoopDefi__ZeroAddress();
            coreTeamWallet[i] = _coreTeam[i];
        }

        for (uint256 i = 0; i < 15; i++) {
            if (_investors[i] == address(0)) revert KhoopDefi__ZeroAddress();
            investorsWallet[i] = _investors[i];
        }

        powerCycleWallet = _powerCycle;
        _registerUser(powerCycleWallet, address(0));
        reserveWallet = _reserve;
        buybackWallet = _buyback;
        usdt = IERC20(_usdt);
    }

    // ============ External Functions ============

    /**
     * @notice Purchase 1-20 entry slots with USDT ($15 per slot)
     * @param numEntries Number of entries to purchase (1-20)
     * @param referrer Referrer address for commission
     */
    function purchaseEntries(uint256 numEntries, address referrer)
        external
        nonReentrant
        whenNotPaused
        validReferrer(referrer)
    {
        if (numEntries == 0 || numEntries > MAX_ENTRIES_PER_TX) {
            revert KhoopDefi__ExceedsTransactionLimit();
        }

        // Check 30-minute cooldown
        if (users[msg.sender].cooldownEnd != 0 && block.timestamp < users[msg.sender].cooldownEnd) {
            revert KhoopDefi__InCooldown();
        }

        uint256 totalCost = ENTRY_COST * numEntries;
        if (usdt.balanceOf(msg.sender) < totalCost) {
            revert KhoopDefi__MustPayExactAmount();
        }

        // Register user if first time
        if (!users[msg.sender].isRegistered) {
            _registerUser(msg.sender, referrer);
        }

        uint256 startId = nextEntryId;

        // Create entries
        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);
        }

        usdt.safeTransferFrom(msg.sender, address(this), totalCost);

        // Update stats
        users[msg.sender].totalEntriesPurchased += numEntries;
        users[msg.sender].cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        globalStats.totalEntriesPurchased += numEntries;
        buybackAccumulated += (numEntries * BUYBACK_PER_ENTRY);

        // Distribute team shares
        _distributeTeamShares(numEntries);

        // Process auto-fills
        _processMultipleAutoFills();

        emit BatchEntryPurchased(startId, nextEntryId - 1, msg.sender, totalCost);
    }

    /**
     * @notice Pay $0.50 to reduce cooldown - get 15 mins or instant access
     * @dev If user has >15 mins left: reduces to 15 mins from now
     * @dev If user has <=15 mins left: gives instant access
     */
    function reduceCooldown() external nonReentrant whenNotPaused {
        User storage user = users[msg.sender];

        // Check if user has ever purchased
        if (user.cooldownEnd == 0) {
            revert KhoopDefi__CooldownNotActive();
        }

        // Check if still in cooldown
        if (block.timestamp >= user.cooldownEnd) {
            revert KhoopDefi__CooldownNotActive();
        }

        if (usdt.balanceOf(msg.sender) < COOLDOWN_FEE) {
            revert KhoopDefi__InsufficientBalance();
        }

        usdt.safeTransferFrom(msg.sender, address(this), COOLDOWN_FEE);

        // Only allow if it actually reduces the cooldown
        uint256 newCooldownEnd = block.timestamp + REDUCED_COOLDOWN;
        if (newCooldownEnd >= user.cooldownEnd) {
            user.cooldownEnd = block.timestamp;
        } else {
            user.cooldownEnd = newCooldownEnd;
        }

        emit CooldownReduced(msg.sender, COOLDOWN_FEE);
    }

    // ============ Internal Functions ============

    function _registerUser(address user, address referrer) internal {
        users[user] = User({
            referrer: referrer,
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true
        });

        if (referrer != address(0)) {
            users[referrer].totalReferrals++;

            // Pay one-time welcome bonus
            if (!referralBonusPaid[user]) {
                referralBonusPaid[user] = true;
                users[referrer].referrerBonusEarned += REFERRER_WELCOME_BONUS;
                globalStats.totalReferrerBonusPaid += REFERRER_WELCOME_BONUS;
                usdt.safeTransfer(referrer, REFERRER_WELCOME_BONUS);
                emit ReferrerBonusPaid(referrer, user, REFERRER_WELCOME_BONUS);
            }
        }

        globalStats.totalUsers++;
        emit UserRegistered(user, referrer);
    }

    function _createEntry(address user) internal {
        entries[nextEntryId] = Entry({
            entryId: nextEntryId,
            owner: user,
            purchaseTimestamp: block.timestamp,
            cyclesCompleted: 0,
            lastCycleTimestamp: block.timestamp,
            isActive: true
        });

        userEntries[user].push(nextEntryId);
        emit EntryPurchased(nextEntryId, user, users[user].referrer, ENTRY_COST);
        nextEntryId++;
    }

    /**
     * @notice Advance queue pointer past inactive/maxed entries - O(1) amortized
     * @dev Each entry only processed once in its lifetime
     */
    function _advancePendingStart() internal {
        while (pendingStartId < nextEntryId) {
            Entry storage entry = entries[pendingStartId];

            // Skip if inactive or maxed out
            if (!entry.isActive || entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
                unchecked {
                    pendingStartId++;
                }
            } else {
                break; // Found active entry
            }
        }
    }

    /**
     * @notice Get next pending entry in queue - O(1) amortized
     */
    function _nextPendingEntry() internal returns (uint256) {
        _advancePendingStart();
        if (pendingStartId >= nextEntryId) return 0;
        return pendingStartId;
    }

    function _distributeTeamShares(uint256 numEntries) internal {
        uint256 totalCorePerWallet = CORE_TEAM_SHARE * numEntries;
        uint256 totalInvestorPerWallet = INVESTORS_SHARE * numEntries;
        uint256 totalContingency = CONTINGENCY_SHARE * numEntries;

        for (uint256 i = 0; i < 4; i++) {
            usdt.safeTransfer(coreTeamWallet[i], totalCorePerWallet);
        }

        for (uint256 i = 0; i < 15; i++) {
            usdt.safeTransfer(investorsWallet[i], totalInvestorPerWallet);
        }

        usdt.safeTransfer(reserveWallet, totalContingency);
        distributedTeamShares += numEntries;
        emit TeamSharesDistributed(numEntries);
    }

    function _processMultipleAutoFills() internal {
        uint256 processed = 0;

        // Process up to 5 auto-fills per purchase
        while (buybackAccumulated >= BUYBACK_THRESHOLD && processed < MAX_AUTO_FILLS_PER_PURCHASE) {
            uint256 oldestEntryId = _nextPendingEntry();
            if (oldestEntryId == 0) break; // No pending entries

            bool success = _processSingleAutoFill(oldestEntryId);
            if (!success) break;

            processed++;
        }

        if (processed > 0) {
            emit MultipleAutoFillsProcessed(processed, buybackAccumulated);
        }
    }

    function _processSingleAutoFill(uint256 entryId) internal returns (bool) {
        Entry storage entry = entries[entryId];

        // Validate entry
        if (entryId == 0 || entry.entryId == 0 || !entry.isActive || entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
            return false;
        }

        if (usdt.balanceOf(address(this)) < CYCLE_PAYOUT) {
            return false;
        }

        // Complete cycle
        entry.cyclesCompleted++;
        entry.lastCycleTimestamp = block.timestamp;

        // Update stats
        users[entry.owner].totalCyclesCompleted++;
        users[entry.owner].totalEarnings += CYCLE_PAYOUT;
        globalStats.totalCyclesCompleted++;
        globalStats.totalPayoutsMade += CYCLE_PAYOUT;

        // Consume buyback
        buybackAccumulated -= BUYBACK_THRESHOLD;

        // Check if maxed out
        if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
            entry.isActive = false;
            emit EntryMaxedOut(entryId, entry.owner);
        }

        // Advance queue pointer
        _advancePendingStart();

        usdt.safeTransfer(entry.owner, CYCLE_PAYOUT);

        emit CycleCompleted(entryId, entry.owner, entry.cyclesCompleted, CYCLE_PAYOUT);
        emit BuybackAutoFill(entryId, BUYBACK_THRESHOLD);

        return true;
    }

    // ============ View Functions ============

    function getUserAllEntries(address user) external view returns (uint256[] memory) {
        return userEntries[user];
    }

    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getBuybackAccumulated() external view returns (uint256) {
        return buybackAccumulated;
    }

    function getQueuePosition() external view returns (uint256) {
        return pendingStartId;
    }

    function getCooldownRemaining(address user) external view returns (uint256) {
        if (users[user].cooldownEnd == 0 || block.timestamp >= users[user].cooldownEnd) {
            return 0;
        }
        return users[user].cooldownEnd - block.timestamp;
    }

    function getEntryDetails(uint256 entryId)
        external
        view
        returns (
            address owner,
            uint256 purchaseTime,
            uint8 cyclesCompleted,
            uint256 lastCycleTime,
            bool isActive,
            uint8 cyclesRemaining
        )
    {
        Entry storage entry = entries[entryId];
        require(entry.entryId != 0, "Entry does not exist");
        return (
            entry.owner,
            entry.purchaseTimestamp,
            entry.cyclesCompleted,
            entry.lastCycleTimestamp,
            entry.isActive,
            entry.isActive ? uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted) : 0
        );
    }

    function getUserStats(address user)
        external
        view
        returns (
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 totalEarnings,
            uint256 totalReferrals
        )
    {
        User storage userStats = users[user];
        return (
            userStats.totalEntriesPurchased,
            userStats.totalCyclesCompleted,
            userStats.referrerBonusEarned,
            userStats.totalEarnings,
            userStats.totalReferrals
        );
    }

    function getGlobalStats()
        external
        view
        returns (
            uint256 totalUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted
        )
    {
        return (
            globalStats.totalUsers,
            globalStats.totalEntriesPurchased,
            globalStats.totalReferrerBonusPaid,
            globalStats.totalPayoutsMade,
            globalStats.totalCyclesCompleted
        );
    }

    function getUserActiveEntries(address user) external view returns (uint256[] memory) {
        uint256[] memory userEntryIds = userEntries[user];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (entries[userEntryIds[i]].isActive) {
                activeCount++;
            }
        }

        uint256[] memory activeEntries = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (entries[userEntryIds[i]].isActive) {
                activeEntries[index] = userEntryIds[i];
                index++;
            }
        }

        return activeEntries;
    }

    function getUserPotentialEarnings(address user) external view returns (uint256) {
        uint256[] memory userEntryIds = userEntries[user];
        uint256 potential = 0;

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            Entry storage entry = entries[userEntryIds[i]];
            if (entry.isActive) {
                uint256 remainingCycles = uint256(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted);
                potential += (remainingCycles * CYCLE_PAYOUT);
            }
        }

        return potential;
    }

    function getNextInLine()
        external
        view
        returns (uint256 entryId, address owner, uint8 cyclesCompleted, bool isActive)
    {
        // Start from the current pendingStartId
        uint256 currentId = pendingStartId;

        // Loop through entries to find the next active one
        while (currentId < nextEntryId) {
            Entry storage entry = entries[currentId];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                return (entry.entryId, entry.owner, entry.cyclesCompleted, entry.isActive);
            }
            currentId++;
        }

        // If no active entries found
        return (0, address(0), 0, false);
    }
}
