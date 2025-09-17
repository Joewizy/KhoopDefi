// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Khoop-Defi
 * @notice Slot-based contribution system with automated payouts and referral rewards
 * @dev Entry: $15, Profit Only: $5, Capital Locked to Powerline
 */
contract KhoopDefi is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error KhoopDefi__ExceedsDailyLimit();
    error KhoopDefi__ExceedsTransactionLimit();
    error KhoopDefi__InsufficientBalance();
    error KhoopDefi__InvalidRefferer();
    error KhoopDefi__CycleNotComplete();
    error KhoopDefi__ZeroAddress();
    error KhoopDefi__TimeCoolDown();
    error KhoopDefi__MustPayExactAmount();
    error KhoopDefi__OnlyEntryOwner();
    error KhoopDefi__CycleAlreadyCompleted();

    // ============ Types ============
    struct User {
        address refferer; // Refferer who gets commission
        uint256 entriesPurchased; // Total entries bought
        uint256 entriesFilled; // Completed cycles
        uint256 reffererBonusEarned; // Commission earned from refferers
        uint256 slotFillEarnings; // Earnings from completed cycles
        uint256 totalReferrals; // Number of direct referrals
        uint256 lastEntryAt; // Anti-spam protection
        uint256 dailyEntries; // Daily entry counter
        uint256 lastDailyReset; // Daily reset timestamp
        bool isRegistered; // Explicit registration flag
    }

    struct Entry {
        uint256 entryId;
        address user;
        uint256 timestamp;
        bool isCompleted;
        uint256 completionTime;
    }

    struct GlobalStats {
        uint256 totalUsers;
        uint256 totalEntriesPurchased;
        uint256 totalReffererBonusPaid;
        uint256 totalSlotFillPaid;
        uint256 totalEntriesCompleted;
    }

    // ============ Constants ============
    uint256 private constant CORE_TEAM_SHARE = 15e16; // $0.15 each (4 wallets)
    uint256 private constant INVESTORS_SHARE = 2e16; // $0.02 each (15 wallets)
    uint256 private constant CONTINGENCY_SHARE = 1e17; // $0.10
    uint256 private constant ENTRY_COST = 15e18; // $15 entry cost (capital)
    uint256 private constant PROFIT_AMOUNT = 5e18; // $5 profit
    uint256 private constant CYCLE_DURATION = 1 days; // 1 day cycle (failsafe)
    uint256 private constant MAX_ENTRIES_PER_TX = 10;
    uint256 private constant MAX_ENTRIES_PER_DAY = 50;
    uint256 private constant REFERRER_WELCOME_BONUS = 1e18; // 1 USDT one-time welcome bonus
    uint256 private constant MIN_ENTRY_INTERVAL = 10 minutes;
    uint256 private constant BUYBACK_PER_ENTRY = 3e18; // $3 per entry
    uint256 private constant BUYBACK_THRESHOLD = 10e18; // $10 threshold

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
    uint256 public buybackAccumulated; // Track accumulated buyback funds
    uint256 public pendingStartId = 1; // Queue pointer to oldest pending entry
    uint256 public distributedTeamShares;
    uint256 public constant MAX_AUTO_FILLS_PER_PURCHASE = 5; // Cap for safety

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed refferer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint256 profitPaid);
    event ReffererBonusPaid(address indexed refferer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed refferer);
    event BalanceWithdrawn(address indexed user, uint256 amount);
    event BatchEntryPurchased(
        uint256 startId, uint256 endId, address indexed user, address indexed refferer, uint256 amount
    );
    event BuybackAutoFill(uint256 indexed entryId, uint256 amount);
    event TeamSharesDistributed(uint256 indexed distributedTeamShares);
    event MultipleAutoFillsProcessed(uint256 count, uint256 remainingBuyback);

    // ============ Modifiers ============
    modifier validRefferer(address refferer) {
        // For new users: require valid referrer
        if (!users[msg.sender].isRegistered) {
            if (refferer == address(0)) {
                revert KhoopDefi__InvalidRefferer();
            }
            if (refferer == msg.sender) {
                revert KhoopDefi__InvalidRefferer();
            }
            if (!users[refferer].isRegistered) {
                revert KhoopDefi__InvalidRefferer();
            }
        }
        // For existing users: allow address(0) (no referrer needed)
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
            coreTeamWallet[i] = _coreTeam[i];
            if (coreTeamWallet[i] == address(0)) {
                revert KhoopDefi__ZeroAddress();
            }
        }
        for (uint256 i = 0; i < 15; i++) {
            investorsWallet[i] = _investors[i];
            if (investorsWallet[i] == address(0)) {
                revert KhoopDefi__ZeroAddress();
            }
        }

        // register powerCycle as the initial refferer
        powerCycleWallet = _powerCycle;
        _registerUser(powerCycleWallet, address(0));
        reserveWallet = _reserve;
        buybackWallet = _buyback;
        usdt = IERC20(_usdt);
    }

    // ============ External Functions ============
    /**
     * @notice Purchase entry slots with USDT ($15 per slot)
     * @param numEntries Number of entries to purchase (max 10 per tx)
     * @param refferer Refferer address for commission
     */
    function purchaseEntries(uint256 numEntries, address refferer)
        external
        nonReentrant
        whenNotPaused
        validRefferer(refferer)
    {
        if (numEntries == 0 || numEntries > MAX_ENTRIES_PER_TX) {
            revert KhoopDefi__ExceedsTransactionLimit();
        }

        // Validate exact payment amount
        uint256 totalCost = ENTRY_COST * numEntries;
        if (usdt.balanceOf(msg.sender) < totalCost) {
            revert KhoopDefi__MustPayExactAmount();
        }

        usdt.safeTransferFrom(msg.sender, address(this), totalCost);

        // Register user if first time
        if (!users[msg.sender].isRegistered) {
            _registerUser(msg.sender, refferer);
        }

        // Check daily limits
        _updateAndCheckDailyLimits(msg.sender, numEntries);

        // 10 minutes cool down
        if (users[msg.sender].lastEntryAt != 0 && block.timestamp < users[msg.sender].lastEntryAt + MIN_ENTRY_INTERVAL)
        {
            revert KhoopDefi__TimeCoolDown();
        }

        // Create entries
        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);
        }

        // Update stats
        users[msg.sender].entriesPurchased += numEntries;
        users[msg.sender].lastEntryAt = block.timestamp;
        globalStats.totalEntriesPurchased += numEntries;
        buybackAccumulated += (numEntries * BUYBACK_PER_ENTRY);

        _distributeTeamShares(numEntries);

        _processMultipleAutoFills();

        emit BatchEntryPurchased(
            nextEntryId - numEntries, // startId
            nextEntryId - 1, // endId
            msg.sender,
            refferer,
            totalCost
        );
    }

    /**
     * @notice Complete a cycle and receive profit only (capital locked to powerline)
     * @param entryId The entry ID to complete
     */
    function completeCycle(uint256 entryId) external nonReentrant whenNotPaused {
        Entry storage entry = entries[entryId];
        if (entry.user != msg.sender) revert KhoopDefi__OnlyEntryOwner();
        if (entry.isCompleted) revert KhoopDefi__CycleAlreadyCompleted();
        if (block.timestamp < entry.timestamp + CYCLE_DURATION) {
            revert KhoopDefi__CycleNotComplete();
        }

        // Check contract balance before payout
        if (usdt.balanceOf(address(this)) < PROFIT_AMOUNT) {
            revert KhoopDefi__InsufficientBalance();
        }

        // Update user stats
        users[msg.sender].entriesFilled++;
        users[msg.sender].slotFillEarnings += PROFIT_AMOUNT;

        // Update global stats
        globalStats.totalEntriesCompleted++;
        globalStats.totalSlotFillPaid += PROFIT_AMOUNT;

        // Mark entry as completed and advance queue pointer
        entry.isCompleted = true;
        entry.completionTime = block.timestamp;
        _advancePendingStart();

        // Pay only profit ($5) - capital ($15) stays locked to powerline
        usdt.safeTransfer(msg.sender, PROFIT_AMOUNT);

        emit CycleCompleted(entryId, msg.sender, PROFIT_AMOUNT);
    }

    // ============ Admin Functions ============
    /**
     * @notice Pause the contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw tokens from contract
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    // ============ Internal Functions ============
    function _registerUser(address user, address refferer) internal {
        users[user] = User({
            refferer: refferer,
            entriesPurchased: 0,
            entriesFilled: 0,
            reffererBonusEarned: 0,
            slotFillEarnings: 0,
            totalReferrals: 0,
            lastEntryAt: 0,
            dailyEntries: 0,
            lastDailyReset: block.timestamp,
            isRegistered: true
        });

        if (refferer != address(0)) {
            users[refferer].totalReferrals++;
            // Pay one-time referral bonus to the refferer for this unique user
            if (!referralBonusPaid[user]) {
                referralBonusPaid[user] = true;
                uint256 bonus = REFERRER_WELCOME_BONUS;
                users[refferer].reffererBonusEarned += bonus;
                globalStats.totalReffererBonusPaid += bonus;
                usdt.safeTransfer(refferer, bonus);
                emit ReffererBonusPaid(refferer, user, bonus);
            }
        }

        globalStats.totalUsers++;
        emit UserRegistered(user, refferer);
    }

    function _advancePendingStart() internal {
        // Advance past entries that are fully completed (isCompleted = true)
        while (pendingStartId < nextEntryId && entries[pendingStartId].isCompleted) {
            unchecked {
                pendingStartId++;
            }
        }
    }

    function _nextPendingEntry() internal returns (uint256) {
        _advancePendingStart();
        if (pendingStartId >= nextEntryId) return 0;
        return pendingStartId;
    }

    function _createEntry(address user) internal {
        entries[nextEntryId] =
            Entry({entryId: nextEntryId, user: user, timestamp: block.timestamp, isCompleted: false, completionTime: 0});

        userEntries[user].push(nextEntryId);
        nextEntryId++;
    }

    function _updateAndCheckDailyLimits(address user, uint256 numEntries) internal {
        if (block.timestamp >= users[user].lastDailyReset + 1 days) {
            users[user].dailyEntries = 0;
            users[user].lastDailyReset = block.timestamp;
        }

        if (users[user].dailyEntries + numEntries > MAX_ENTRIES_PER_DAY) {
            revert KhoopDefi__ExceedsDailyLimit();
        }

        users[user].dailyEntries += numEntries;
    }

    // ============ Buyback Auto-Fill Functions ============
    function _processMultipleAutoFills() internal {
        uint256 processed = 0;
        uint256 maxIterations = MAX_AUTO_FILLS_PER_PURCHASE;

        // Autofill 5 entries at a time
        while (buybackAccumulated >= BUYBACK_THRESHOLD && processed < maxIterations) {
            uint256 oldestEntryId = _nextPendingEntry();
            if (oldestEntryId == 0) break; // No pending entries

            // Try to autofill one entry
            bool success = _processSingleAutoFill(oldestEntryId);
            if (!success) break; // Stop on failure

            processed++;
        }

        if (processed > 0) {
            emit MultipleAutoFillsProcessed(processed, buybackAccumulated);
        }
    }

    function _processSingleAutoFill(uint256 entryId) internal returns (bool) {
        Entry storage entry = entries[entryId];

        // Validate entry exists and is not completed
        if (entryId == 0 || entry.entryId == 0 || entry.isCompleted) {
            return false;
        }

        if (usdt.balanceOf(address(this)) < PROFIT_AMOUNT) {
            return false;
        }

        // Update user stats
        users[entry.user].entriesFilled++;
        users[entry.user].slotFillEarnings += PROFIT_AMOUNT;

        // Update global stats
        globalStats.totalEntriesCompleted++;
        globalStats.totalSlotFillPaid += PROFIT_AMOUNT;

        // Consume buyback threshold
        buybackAccumulated -= BUYBACK_THRESHOLD;

        // Mark entry as completed and pay profit only
        entry.isCompleted = true;
        entry.completionTime = block.timestamp;
        usdt.safeTransfer(entry.user, PROFIT_AMOUNT);

        // Advance queue pointer
        _advancePendingStart();

        emit CycleCompleted(entryId, entry.user, PROFIT_AMOUNT);
        emit BuybackAutoFill(entryId, BUYBACK_THRESHOLD);

        return true;
    }

    /**
     * @notice Distribute team shares immediately on each purchase
     * @dev Fixed $1 per entry distributed to team (60% core team, 30% investors, 10% contingency)
     */
    function _distributeTeamShares(uint256 numEntries) internal {
        uint256 totalCorePerWallet = CORE_TEAM_SHARE * numEntries;
        uint256 totalInvestorPerWallet = INVESTORS_SHARE * numEntries;
        uint256 totalContingency = CONTINGENCY_SHARE * numEntries;

        // Distribute to core team
        for (uint256 i = 0; i < 4; i++) {
            usdt.safeTransfer(coreTeamWallet[i], totalCorePerWallet);
        }

        // Distribute to investors
        for (uint256 i = 0; i < 15; i++) {
            usdt.safeTransfer(investorsWallet[i], totalInvestorPerWallet);
        }

        // Distribute to contingency (reserve) wallet
        usdt.safeTransfer(reserveWallet, totalContingency);
        distributedTeamShares += numEntries;
        emit TeamSharesDistributed(distributedTeamShares);
    }

    // ============ Getter Functions ============
    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getBuybackAccumulated() external view returns (uint256) {
        return buybackAccumulated;
    }

    function getDistributedTeamShares() external view returns (uint256) {
        return distributedTeamShares;
    }

    /**
     * @notice Get user statistics for dashboard
     */
    function getUserStats(address user)
        external
        view
        returns (
            uint256 entriesPurchased,
            uint256 entriesFilled,
            uint256 reffererBonusEarned,
            uint256 slotFillEarnings,
            uint256 totalReferrals
        )
    {
        User storage userStats = users[user];
        return (
            userStats.entriesPurchased,
            userStats.entriesFilled,
            userStats.reffererBonusEarned,
            userStats.slotFillEarnings,
            userStats.totalReferrals
        );
    }

    /**
     * @notice Get global statistics
     */
    function getGlobalStats()
        external
        view
        returns (
            uint256 totalUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReffererBonusPaid,
            uint256 totalSlotFillPaid,
            uint256 totalEntriesCompleted
        )
    {
        return (
            globalStats.totalUsers,
            globalStats.totalEntriesPurchased,
            globalStats.totalReffererBonusPaid,
            globalStats.totalSlotFillPaid,
            globalStats.totalEntriesCompleted
        );
    }

    /**
     * @notice Get user's pending entries
     */
    function getUserPendingEntries(address user) external view returns (uint256[] memory) {
        uint256[] memory userEntryIds = userEntries[user];
        uint256 pendingCount = 0;

        // Count pending entries
        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (!entries[userEntryIds[i]].isCompleted) {
                pendingCount++;
            }
        }

        // Create array of pending entry IDs
        uint256[] memory pendingEntries = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (!entries[userEntryIds[i]].isCompleted) {
                pendingEntries[index] = userEntryIds[i];
                index++;
            }
        }

        return pendingEntries;
    }
}
