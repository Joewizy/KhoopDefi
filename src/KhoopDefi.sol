// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title KhoopDefi - Sequential Round-Robin Distribution
 * @notice Referral & team earn: 1x at purchase + cycles 1,2,3 (NOT cycle 4)
 * @dev Total 4 payments per slot: purchase + first 3 cycles only
 */
contract KhoopDefi is Ownable, ReentrancyGuard {
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
    error KhoopDefi__InvalidAmount();
    error KhoopDefi__GasLimitReached();

    // ============ Types ============
    struct User {
        address referrer;
        uint256 totalEntriesPurchased;
        uint256 totalCyclesCompleted;
        uint256 referrerBonusEarned;
        uint256 referrerBonusMissed;
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
        uint256 totalReferrerBonusMissed;
        uint256 totalPayoutsMade;
        uint256 totalCyclesCompleted;
        uint256 totalSlotsRemaining;
    }

    // ============ Constants ============
    uint256 private constant CORE_TEAM_SHARE = 15e16;
    uint256 private constant INVESTORS_SHARE = 2e16;
    uint256 private constant CONTINGENCY_SHARE = 1e17;
    uint256 private constant ENTRY_COST = 15e18;
    uint256 private constant CYCLE_PAYOUT = 5e18;
    uint256 private constant MAX_CYCLES_PER_ENTRY = 4;
    uint256 private constant LAST_CYCLE = 4;
    uint256 private constant MAX_ENTRIES_PER_TX = 20;
    uint256 private constant REFERRER_ENTRY_BONUS = 1e18;
    uint256 private constant COOLDOWN_PERIOD = 30 minutes;
    uint256 private constant REDUCED_COOLDOWN = 15 minutes;
    uint256 private constant COOLDOWN_FEE = 5e17;
    uint256 private constant TOTAL_TEAM_SHARE = (CORE_TEAM_SHARE * 4) + (INVESTORS_SHARE * 15) + CONTINGENCY_SHARE;

    // ============ Immutable State Variables ============
    IERC20 public immutable usdt;
    address[4] public coreTeamWallet;
    address[15] public investorsWallet;
    address public immutable reserveWallet;
    address public immutable powerCycleWallet;

    // ============ Mappings ============
    mapping(address => User) public users;
    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;
    mapping(address => address[]) public userReferrals;

    // Queue management
    uint256[] public entryQueue;
    uint256 public nextEntryIndex;

    // ============ Global Tracking ============
    GlobalStats public globalStats;
    uint256 public nextEntryId = 1;
    uint256 private teamAccumulatedBalance;

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed referrer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint8 cycleNumber, uint256 payoutAmount);
    event EntryMaxedOut(uint256 indexed entryId, address indexed user);
    event ReferralAdded(address indexed referrer, address indexed referred);
    event ReferrerBonusPaid(address indexed referrer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed referrer);
    event BatchEntryPurchased(uint256 startId, uint256 endId, address indexed user, uint256 totalCost);
    event CooldownReduced(address indexed user, uint256 feePaid);
    event TeamSharesDistributed(uint256 totalAmount);
    event CyclesProcessed(uint256 count, uint256 totalPaid);
    event SystemDonation(address indexed donor, uint256 amount);
    event EmergencyWithdraw(address indexed donor, uint256 amount);
    event ReferralBonusSkipped(uint256 indexed entryId, address indexed referrer);

    // ============ Constructor ============
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _powerCycle,
        address _usdt
    ) Ownable(msg.sender) {
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

        reserveWallet = _reserve;
        powerCycleWallet = _powerCycle;
        usdt = IERC20(_usdt);

        users[powerCycleWallet] = User({
            referrer: address(0),
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            referrerBonusMissed: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true,
            isActive: true
        });
        globalStats.totalUsers++;
        globalStats.totalActiveUsers++;
        emit UserRegistered(powerCycleWallet, address(0));
    }

    // ============ External Functions ============

    function registerUser(address user, address referrer) external {
        if (user == referrer) revert KhoopDefi__SelfReferral();
        if (users[user].isRegistered) revert KhoopDefi__UserAlreadyRegistered();
        if (referrer != address(0) && !users[referrer].isRegistered) {
            revert KhoopDefi__UnregisteredReferrer();
        }

        users[user] = User({
            referrer: referrer,
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            referrerBonusMissed: 0,
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

    function purchaseEntries(uint256 numEntries) external nonReentrant {
        if (!users[msg.sender].isRegistered) revert KhoopDefi__UserNotRegistered();
        if (numEntries == 0 || numEntries > MAX_ENTRIES_PER_TX) {
            revert KhoopDefi__ExceedsTransactionLimit();
        }
        if (users[msg.sender].cooldownEnd != 0 && block.timestamp < users[msg.sender].cooldownEnd) {
            revert KhoopDefi__InCooldown();
        }

        uint256 totalCost = ENTRY_COST * numEntries;
        if (usdt.balanceOf(msg.sender) < totalCost) revert KhoopDefi__MustPayExactAmount();

        uint256 startId = nextEntryId;

        usdt.safeTransferFrom(msg.sender, address(this), totalCost);
        bool userReferrerIsActive = users[msg.sender].isActive;

        // FIXED: Proper loop with closing brace
        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);

            // Check for missed initial referral bonus
            address userReferrer = users[msg.sender].referrer;
            if (userReferrer != address(0) && !userReferrerIsActive) {
                users[userReferrer].referrerBonusMissed += REFERRER_ENTRY_BONUS;
                globalStats.totalReferrerBonusMissed += REFERRER_ENTRY_BONUS;
                emit ReferralBonusSkipped(nextEntryId - 1, userReferrer);
            }
        }

        if (!userReferrerIsActive) {
            _updateUserActiveStatus(msg.sender);
        }
        users[msg.sender].totalEntriesPurchased += numEntries;
        users[msg.sender].cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        globalStats.totalEntriesPurchased += numEntries;

        _processAvailableCycles();

        emit BatchEntryPurchased(startId, nextEntryId - 1, msg.sender, totalCost);
    }

    function reduceCooldown() external nonReentrant {
        User storage user = users[msg.sender];

        if (user.cooldownEnd == 0) revert KhoopDefi__CooldownNotActive();
        if (block.timestamp >= user.cooldownEnd) revert KhoopDefi__CooldownNotActive();
        if (usdt.balanceOf(msg.sender) < COOLDOWN_FEE) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransferFrom(msg.sender, address(this), COOLDOWN_FEE);

        uint256 newCooldownEnd = block.timestamp + REDUCED_COOLDOWN;
        user.cooldownEnd = newCooldownEnd >= user.cooldownEnd ? block.timestamp : newCooldownEnd;

        emit CooldownReduced(msg.sender, COOLDOWN_FEE);
        _processAvailableCycles();
    }

    function completeCycles() external nonReentrant {
        uint256 processed = _processAvailableCycles();
        if (processed == 0) revert KhoopDefi__NoActiveCycles();
    }

    function donateToSystem(uint256 amount) external nonReentrant {
        if (amount == 0) revert KhoopDefi__InvalidAmount();
        if (usdt.balanceOf(msg.sender) < amount) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransferFrom(msg.sender, address(this), amount);
        emit SystemDonation(msg.sender, amount);
        _processAvailableCycles();
    }

    function emergencyWithdraw(uint256 amount) external nonReentrant onlyOwner {
        if (amount == 0) revert KhoopDefi__InvalidAmount();
        if (usdt.balanceOf(address(this)) < amount) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // ============ Internal Functions ============

    function _createEntry(address user) internal {
        uint256 entryId = nextEntryId;

        entries[entryId] = Entry({
            entryId: entryId,
            owner: user,
            purchaseTimestamp: block.timestamp,
            cyclesCompleted: 0,
            lastCycleTimestamp: block.timestamp,
            isActive: true
        });

        userEntries[user].push(entryId);
        entryQueue.push(entryId);

        globalStats.totalSlotsRemaining += MAX_CYCLES_PER_ENTRY;

        address userReferrer = users[user].referrer;
        if (userReferrer != address(0) && users[userReferrer].isActive) {
            _payReferralBonus(userReferrer, REFERRER_ENTRY_BONUS, user);
        }
        _distributeTeamShares();

        emit EntryPurchased(entryId, user, userReferrer, ENTRY_COST);
        nextEntryId++;
    }

    function _payReferralBonus(address referrer, uint256 amount, address referred) internal {
        users[referrer].referrerBonusEarned += amount;
        globalStats.totalReferrerBonusPaid += amount;
        usdt.safeTransfer(referrer, amount);
        emit ReferrerBonusPaid(referrer, referred, amount);
    }

    function _distributeTeamShares() internal {
        uint256 totalCorePerWallet = CORE_TEAM_SHARE;
        uint256 totalInvestorPerWallet = INVESTORS_SHARE;
        uint256 totalContingency = CONTINGENCY_SHARE;

        for (uint256 i = 0; i < 4; i++) {
            usdt.safeTransfer(coreTeamWallet[i], totalCorePerWallet);
        }

        for (uint256 i = 0; i < 15; i++) {
            usdt.safeTransfer(investorsWallet[i], totalInvestorPerWallet);
        }

        usdt.safeTransfer(reserveWallet, totalContingency);

        uint256 totalDistributed = (totalCorePerWallet * 4) + (totalInvestorPerWallet * 15) + totalContingency;
        teamAccumulatedBalance += totalDistributed;
        emit TeamSharesDistributed(totalDistributed);
    }

    function _processAvailableCycles() internal returns (uint256 totalCyclesProcessed) {
        if (entryQueue.length == 0) return 0;

        uint256 balance = usdt.balanceOf(address(this));
        uint256 minGas = 50_000;
        uint256 startIndex = nextEntryIndex;
        uint256 totalEntries = entryQueue.length;
        uint256 maxConsecutiveSkips = entryQueue.length;
        uint256 consecutiveSkips = 0;

        while (consecutiveSkips < maxConsecutiveSkips) {
            if (gasleft() < minGas) break;

            uint256 entryId = entryQueue[nextEntryIndex];
            Entry storage entry = entries[entryId];

            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                bool isLastCycle = (entry.cyclesCompleted + 1 == LAST_CYCLE);

                address userReferrer = users[entry.owner].referrer;
                bool shouldPayReferrer = !isLastCycle && userReferrer != address(0) && users[userReferrer].isActive;

                bool shouldPayTeam = !isLastCycle;

                uint256 requiredBalance = CYCLE_PAYOUT;
                if (shouldPayReferrer) requiredBalance += REFERRER_ENTRY_BONUS;
                if (shouldPayTeam) requiredBalance += TOTAL_TEAM_SHARE;

                if (balance < requiredBalance) {
                    break;
                }

                if (shouldPayTeam) {
                    _distributeTeamShares();
                }

                if (shouldPayReferrer) {
                    _payReferralBonus(userReferrer, REFERRER_ENTRY_BONUS, entry.owner);
                } else if (!isLastCycle && userReferrer != address(0) && !users[userReferrer].isActive) {
                    users[userReferrer].referrerBonusMissed += REFERRER_ENTRY_BONUS;
                    globalStats.totalReferrerBonusMissed += REFERRER_ENTRY_BONUS;
                    emit ReferralBonusSkipped(entryId, userReferrer);
                }

                entry.cyclesCompleted++;
                entry.lastCycleTimestamp = block.timestamp;
                users[entry.owner].totalCyclesCompleted++;
                users[entry.owner].totalEarnings += CYCLE_PAYOUT;
                globalStats.totalCyclesCompleted++;
                globalStats.totalPayoutsMade += CYCLE_PAYOUT;
                globalStats.totalSlotsRemaining--;

                usdt.safeTransfer(entry.owner, CYCLE_PAYOUT);
                balance -= requiredBalance;
                totalCyclesProcessed++;
                consecutiveSkips = 0;

                emit CycleCompleted(entryId, entry.owner, entry.cyclesCompleted, CYCLE_PAYOUT);

                if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
                    entry.isActive = false;
                    _updateUserActiveStatus(entry.owner);
                    emit EntryMaxedOut(entryId, entry.owner);
                }
            } else {
                consecutiveSkips++;
            }

            nextEntryIndex = (nextEntryIndex + 1) % totalEntries;

            if (nextEntryIndex == startIndex) {
                if (totalCyclesProcessed == 0) break;
                startIndex = nextEntryIndex;
            }
        }

        if (totalCyclesProcessed > 0) {
            emit CyclesProcessed(totalCyclesProcessed, totalCyclesProcessed * CYCLE_PAYOUT);
        }

        return totalCyclesProcessed;
    }

    function _hasPendingCycles(address user) internal view returns (bool) {
        uint256[] storage userSlots = userEntries[user];

        for (uint256 i = 0; i < userSlots.length; i++) {
            Entry storage entry = entries[userSlots[i]];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                return true;
            }
        }

        return false;
    }

    function _updateUserActiveStatus(address user) internal {
        bool hasActiveEntries = false;
        uint256[] storage userEntryIds = userEntries[user];

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            Entry storage entry = entries[userEntryIds[i]];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                hasActiveEntries = true;
                break;
            }
        }

        if (users[user].isActive != hasActiveEntries) {
            users[user].isActive = hasActiveEntries;
            if (hasActiveEntries) {
                globalStats.totalActiveUsers++;
            } else {
                globalStats.totalActiveUsers--;
            }
        }
    }

    // ============ View Functions ============

    function getUserAllEntries(address user) external view returns (uint256[] memory) {
        return userEntries[user];
    }

    function isUserActive(address user) external view returns (bool) {
        return users[user].isActive;
    }

    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getTeamAccumulatedBalance() external view returns (uint256) {
        return teamAccumulatedBalance;
    }

    function getCooldownRemaining(address user) external view returns (uint256) {
        if (users[user].cooldownEnd == 0 || block.timestamp >= users[user].cooldownEnd) {
            return 0;
        }
        return users[user].cooldownEnd - block.timestamp;
    }

    function getNextInLine()
        external
        view
        returns (uint256 entryId, address owner, uint8 cyclesCompleted, uint8 cyclesRemaining, bool isActive)
    {
        uint256 totalEntries = entryQueue.length;
        if (totalEntries == 0) return (0, address(0), 0, 0, false);

        uint256 currentId = entryQueue[nextEntryIndex];
        Entry storage entry = entries[currentId];

        if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
            return (
                currentId, entry.owner, entry.cyclesCompleted, uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted), true
            );
        }

        uint256 nextValidIndex = (nextEntryIndex + 1) % totalEntries;
        for (uint256 i = 0; i < totalEntries; i++) {
            currentId = entryQueue[nextValidIndex];
            entry = entries[currentId];

            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                return (
                    currentId,
                    entry.owner,
                    entry.cyclesCompleted,
                    uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted),
                    true
                );
            }

            nextValidIndex = (nextValidIndex + 1) % totalEntries;
        }

        return (0, address(0), 0, 0, false);
    }

    function getPendingCyclesCount() external view returns (uint256 totalPendingCycles) {
        return globalStats.totalSlotsRemaining;
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
            uint256 referrerBonusMissed,
            uint256 totalEarnings,
            uint256 totalReferrals,
            bool isActive
        )
    {
        User storage userStats = users[user];
        return (
            userStats.totalEntriesPurchased,
            userStats.totalCyclesCompleted,
            userStats.referrerBonusEarned,
            userStats.referrerBonusMissed,
            userStats.totalEarnings,
            userStats.totalReferrals,
            userStats.isActive
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
            uint256 totalReferrerBonusMissed,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted,
            uint256 totalSlotsRemaining
        )
    {
        return (
            globalStats.totalUsers,
            globalStats.totalActiveUsers,
            globalStats.totalEntriesPurchased,
            globalStats.totalReferrerBonusPaid,
            globalStats.totalReferrerBonusMissed,
            globalStats.totalPayoutsMade,
            globalStats.totalCyclesCompleted,
            globalStats.totalSlotsRemaining
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

    function getInactiveReferrals(address referrer) external view returns (address[] memory) {
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

        address[] memory inactiveReferrals = new address[](inactiveCount);
        for (uint256 i = 0; i < inactiveCount; i++) {
            inactiveReferrals[i] = tempInactive[i];
        }

        return inactiveReferrals;
    }

    function userHasPendingCycles(address user) external view returns (bool) {
        return _hasPendingCycles(user);
    }
}
