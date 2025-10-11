// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Khoop-Defi
 * @notice Sustainable slot-based system with 4-cycle cap and immediate payouts
 */
contract KhoopDefiV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error KhoopDefi__ExceedsTransactionLimit();
    error KhoopDefi__InsufficientBalance();
    error KhoopDefi__SelfReferral();
    error KhoopDefi__UnregisteredReferrer();
    error KhoopDefi__ZeroAddress();
    error KhoopDefi__InCooldown();
    error KhoopDefi__MustPayExactAmount();
    error KhoopDefi__CooldownNotActive();
    error KhoopDefi__UserNotRegistered();
    error KhoopDefi__UserAlreadyRegistered();
    error KhoopDefi__NoActiveCycles();
    error KhoopDefi__InsufficientContractBalance();

    // ============ Types ============
    struct User {
        address referrer;
        uint256 totalEntriesPurchased;
        uint256 totalCyclesCompleted;
        uint256 referrerBonusEarned;
        uint256 totalEarnings;
        uint256 totalReferrals;
        uint256 cooldownEnd;
        bool isRegistered;
        bool isActive;
    }

    struct Entry {
        uint256 entryId;
        address owner;
        uint256 purchaseTimestamp;
        uint8 cyclesCompleted;
        uint256 lastCycleTimestamp;
        bool isActive;
    }

    struct GlobalStats {
        uint256 totalUsers;
        uint256 totalActiveUsers;
        uint256 totalEntriesPurchased;
        uint256 totalReferrerBonusPaid;
        uint256 totalPayoutsMade;
        uint256 totalCyclesCompleted;
    }

    // ============ Constants ============
    uint256 private constant CORE_TEAM_SHARE = 15e16; // 0.15 USDT per entry
    uint256 private constant INVESTORS_SHARE = 2e16; // 0.02 USDT per entry per investor
    uint256 private constant CONTINGENCY_SHARE = 1e17; // 0.10 USDT per entry
    uint256 private constant ENTRY_COST = 15e18; // 15 USDT
    uint256 private constant CYCLE_PAYOUT = 5e18; // 5 USDT
    uint256 private constant MAX_CYCLES_PER_ENTRY = 4;
    uint256 private constant MAX_ENTRIES_PER_TX = 20;
    uint256 private constant REFERRER_ENTRY_BONUS = 1e18; // 1 USDT per entry
    uint256 private constant COOLDOWN_PERIOD = 30 minutes;
    uint256 private constant REDUCED_COOLDOWN = 15 minutes;
    uint256 private constant COOLDOWN_FEE = 5e17; // 0.50 USDT

    // ============ State Variables ============
    address[4] public coreTeamWallet;
    address[15] public investorsWallet;
    address public reserveWallet;
    address public powerCycleWallet;

    IERC20 public immutable usdt;

    // ============ Mappings ============
    mapping(address => User) public users;
    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;
    mapping(address => address[]) public userReferrals;

    // ============ Global Tracking ============
    GlobalStats public globalStats;
    uint256 public nextEntryId = 1;
    uint256 public pendingStartId = 1;
    uint256 public distributedTeamShares;

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed referrer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint8 cycleNumber, uint256 payoutAmount);
    event EntryMaxedOut(uint256 indexed entryId, address indexed user);
    event ReferralAdded(address indexed referrer, address indexed referred);
    event ReferrerBonusPaid(address indexed referrer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed referrer);
    event BatchEntryPurchased(uint256 startId, uint256 endId, address indexed user, uint256 totalCost);
    event CooldownReduced(address indexed user, uint256 feePaid);
    event TeamSharesDistributed(uint256 totalEntries);
    event CyclesProcessed(uint256 count, uint256 totalPaid);

    // ============ Constructor ============
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _powerCycle,
        address _usdt
    ) {
        if (_reserve == address(0) || _powerCycle == address(0) || _usdt == address(0)) {
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
        reserveWallet = _reserve;
        usdt = IERC20(_usdt);

        users[powerCycleWallet] = User({
            referrer: address(0xa2791e44234Dc9C96F260aD15fdD09Fe9B597FE1),
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true,
            isActive: true
        });
        globalStats.totalUsers++;
        emit UserRegistered(powerCycleWallet, address(0));
    }

    // ============ External Functions ============

    /**
     * @notice Register a new user with a referrer
     * @param user Address of the user to register
     * @param referrer Address of the referrer (can be zero for no referrer)
     */
    function registerUser(address user, address referrer) external {
        if (user == referrer) {
            revert KhoopDefi__SelfReferral();
        }
        if (users[user].isRegistered) {
            revert KhoopDefi__UserAlreadyRegistered();
        }
        if (referrer != address(0) && !users[referrer].isRegistered) {
            revert KhoopDefi__UnregisteredReferrer();
        }

        users[user] = User({
            referrer: referrer,
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true,
            isActive: false
        });

        if (referrer != address(0)) {
            userReferrals[referrer].push(user);
            users[referrer].totalReferrals++;
            emit ReferralAdded(referrer, user);
        }

        globalStats.totalUsers++;
        emit UserRegistered(user, referrer);
    }

    /**
     * @notice Purchase 1-20 entry slots with USDT ($15 per slot)
     * @param numEntries Number of entries to purchase (1-20)
     */
    function purchaseEntries(uint256 numEntries) external nonReentrant {
        if (!users[msg.sender].isRegistered) {
            revert KhoopDefi__UserNotRegistered();
        }
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

        uint256 startId = nextEntryId;

        usdt.safeTransferFrom(msg.sender, address(this), totalCost);

        // Create entries
        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);
        }

        // Update stats
        if (!users[msg.sender].isActive) {
            users[msg.sender].isActive = true;
            globalStats.totalActiveUsers++;
        }
        users[msg.sender].totalEntriesPurchased += numEntries;
        users[msg.sender].cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        globalStats.totalEntriesPurchased += numEntries;

        // Pay referral bonus if referrer is active
        address userReferrer = users[msg.sender].referrer;
        if (userReferrer != address(0) && users[userReferrer].isActive) {
            uint256 totalBonus = numEntries * REFERRER_ENTRY_BONUS;
            _payReferralBonus(userReferrer, totalBonus);
        }

        // Distribute team shares
        _distributeTeamShares(numEntries);

        // Process pending cycles with remaining balance
        _processAvailableCycles();

        emit BatchEntryPurchased(startId, nextEntryId - 1, msg.sender, totalCost);
    }

    /**
     * @notice Pay $0.50 to reduce cooldown - get 15 mins or instant access
     * @dev If user has >15 mins left: reduces to 15 mins from now
     * @dev If user has <=15 mins left: gives instant access
     */
    function reduceCooldown() external nonReentrant {
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

        // Process pending cycles with the cooldown fee
        _processAvailableCycles();
    }

    /**
     * @notice Manually complete pending cycles
     * @dev Anyone can call this to process cycles using available contract balance
     */
    function completeCycles() external nonReentrant {
        uint256 processed = _processAvailableCycles();
        if (processed == 0) {
            revert KhoopDefi__NoActiveCycles();
        }
    }

    // ============ Internal Functions ============

    function _payReferralBonus(address referrer, uint256 amount) internal {
        users[referrer].referrerBonusEarned += amount;
        globalStats.totalReferrerBonusPaid += amount;
        usdt.safeTransfer(referrer, amount);
        emit ReferrerBonusPaid(referrer, msg.sender, amount);
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

    /**
     * @notice Process as many cycles as possible with available contract balance
     * @return processed Number of cycles completed
     */
    function _processAvailableCycles() internal returns (uint256 processed) {
        uint256 availableBalance = usdt.balanceOf(address(this));
        uint256 totalPaid = 0;

        while (availableBalance >= CYCLE_PAYOUT) {
            uint256 nextId = _nextPendingEntry();
            if (nextId == 0) break; // No pending entries

            bool success = _processSingleCycle(nextId);
            if (!success) break;

            processed++;
            totalPaid += CYCLE_PAYOUT;
            availableBalance -= CYCLE_PAYOUT;
        }

        if (processed > 0) {
            emit CyclesProcessed(processed, totalPaid);
        }

        return processed;
    }

    /**
     * @notice Process a single cycle for an entry
     * @param entryId The entry ID to process
     * @return success Whether the cycle was successfully completed
     */
    function _processSingleCycle(uint256 entryId) internal returns (bool) {
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

        // Check if maxed out
        if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
            entry.isActive = false;
            emit EntryMaxedOut(entryId, entry.owner);
        }

        // Advance queue pointer
        _advancePendingStart();

        // Send payout
        usdt.safeTransfer(entry.owner, CYCLE_PAYOUT);

        emit CycleCompleted(entryId, entry.owner, entry.cyclesCompleted, CYCLE_PAYOUT);

        return true;
    }

    // ============ View Functions ============

    function getUserAllEntries(address user) external view returns (uint256[] memory) {
        return userEntries[user];
    }

    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
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
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted
        )
    {
        return (
            globalStats.totalUsers,
            globalStats.totalActiveUsers,
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

    function getInactiveReferrals(address referrer) external view returns (address[] memory inactiveReferrals) {
        address[] storage referrals = userReferrals[referrer];
        uint256 totalReferrals = referrals.length;
        address[] memory tempInactive = new address[](totalReferrals);
        uint256 inactiveCount = 0;

        for (uint256 i = 0; i < totalReferrals; i++) {
            if (!users[referrals[i]].isActive) {
                tempInactive[inactiveCount] = referrals[i];
                inactiveCount++;
            }
        }

        // Create a new array with the correct size
        inactiveReferrals = new address[](inactiveCount);
        for (uint256 i = 0; i < inactiveCount; i++) {
            inactiveReferrals[i] = tempInactive[i];
        }

        return inactiveReferrals;
    }

    function getNextInLine()
        external
        view
        returns (uint256 entryId, address owner, uint8 cyclesCompleted, bool isActive)
    {
        // Start from the current pendingStartId.
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

    /**
     * @notice Get the number of pending cycles that can be completed with current balance
     */
    function getPendingCyclesCount() external view returns (uint256 count) {
        uint256 availableBalance = usdt.balanceOf(address(this));
        uint256 currentId = pendingStartId;

        while (availableBalance >= CYCLE_PAYOUT && currentId < nextEntryId) {
            Entry storage entry = entries[currentId];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                count++;
                availableBalance -= CYCLE_PAYOUT;
            }
            currentId++;
        }

        return count;
    }
}
