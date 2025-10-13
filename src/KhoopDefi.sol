// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title KhoopDefi - Sequential Round-Robin Distribution
 * @notice Each user completes 1 cycle on ALL slots in order before next user
 * @dev Strict FIFO - cannot skip slots, must process in exact order
 */
contract KhoopDefi is ReentrancyGuard {
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
    error KhoopDefi__WithdrawalDoesNotExist();
    error KhoopDefi__WithdrawalAlreadyExecuted();
    error KhoopDefi__InsufficientConfirmations();
    error KhoopDefi__TimelockNotExpired();
    error KhoopDefi__AlreadyConfirmed();
    error KhoopDefi__NotASigner();
    error KhoopDefi__InvalidAmount();
    error KhoopDefi__InvalidSignatures();
    error KhoopDefi__GasLimitExceeded();

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

    struct UserRoundInfo {
        bool inQueue;
    }

    struct GlobalStats {
        uint256 totalUsers;
        uint256 totalActiveUsers;
        uint256 totalEntriesPurchased;
        uint256 totalReferrerBonusPaid;
        uint256 totalPayoutsMade;
        uint256 totalCyclesCompleted;
    }

    struct Withdrawal {
        address to;
        uint256 amount;
        uint256 unlockTime;
        uint256 confirmations;
        bool executed;
        mapping(address => bool) isConfirmed;
    }

    // ============ Constants ============
    uint256 private constant CORE_TEAM_SHARE = 15e16;
    uint256 private constant INVESTORS_SHARE = 2e16;
    uint256 private constant CONTINGENCY_SHARE = 1e17;
    uint256 private constant ENTRY_COST = 15e18;
    uint256 private constant CYCLE_PAYOUT = 5e18;
    uint256 private constant MAX_CYCLES_PER_ENTRY = 4;
    uint256 private constant MAX_ENTRIES_PER_TX = 20;
    uint256 private constant REFERRER_ENTRY_BONUS = 1e18;
    uint256 private constant COOLDOWN_PERIOD = 30 minutes;
    uint256 private constant REDUCED_COOLDOWN = 15 minutes;
    uint256 private constant COOLDOWN_FEE = 5e17;
    uint256 private constant TIMELOCK_DURATION = 2 days;

    // ============ Immutable State Variables ============
    IERC20 public immutable usdt;
    address[4] public coreTeamWallet;
    address[15] public investorsWallet;
    address public immutable reserveWallet;
    address public immutable powerCycleWallet;

    // ============ Mutable State Variables ============
    address[] public signers;
    uint256 public requiredSignatures;

    // ============ Mappings ============
    mapping(address => User) public users;
    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;
    mapping(address => address[]) public userReferrals;
    mapping(bytes32 => Withdrawal) public withdrawals;
    mapping(address => UserRoundInfo) public userRoundInfo;

    // Queue management
    address[] public queueOrder;
    uint256 public currentQueueIndex;
    mapping(address => uint256) private _queueIndex; // Tracks index of each user in queueOrder

    // ============ Global Tracking ============
    GlobalStats public globalStats;
    uint256 public nextEntryId = 1;

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed referrer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint8 cycleNumber, uint256 payoutAmount);
    event RoundCompleted(address indexed user, uint256 roundNumber, uint256 slotsCompleted, uint256 totalPaid);
    event EntryMaxedOut(uint256 indexed entryId, address indexed user);
    event ReferralAdded(address indexed referrer, address indexed referred);
    event ReferrerBonusPaid(address indexed referrer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed referrer);
    event BatchEntryPurchased(uint256 startId, uint256 endId, address indexed user, uint256 totalCost);
    event CooldownReduced(address indexed user, uint256 feePaid);
    event TeamSharesDistributed(uint256 totalEntries, uint256 totalAmount);
    event CyclesProcessed(uint256 count, uint256 totalPaid);
    event SystemDonation(address indexed donor, uint256 amount);
    event WithdrawalInitiated(bytes32 indexed withdrawalId, address indexed to, uint256 amount, uint256 unlockTime);
    event WithdrawalConfirmed(bytes32 indexed withdrawalId, address indexed signer);
    event WithdrawalExecuted(bytes32 indexed withdrawalId, address indexed to, uint256 amount);
    event UserAddedToQueue(address indexed user);
    event UserRemovedFromQueue(address indexed user);

    // ============ Modifiers ============
    modifier onlySigner() {
        bool isSigner = false;
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        if (!isSigner) revert KhoopDefi__NotASigner();
        _;
    }

    // ============ Constructor ============
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _powerCycle,
        address[] memory _signers,
        uint256 _requiredSignatures,
        address _usdt
    ) {
        if (_reserve == address(0) || _powerCycle == address(0) || _usdt == address(0)) {
            revert KhoopDefi__ZeroAddress();
        }
        if (_signers.length == 0 || _requiredSignatures == 0 || _requiredSignatures > _signers.length) {
            revert KhoopDefi__InvalidSignatures();
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
        signers = _signers;
        requiredSignatures = _requiredSignatures;

        users[powerCycleWallet] = User({
            referrer: address(0),
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

        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);
        }

        if (!users[msg.sender].isActive) {
            _updateUserActiveStatus(msg.sender);
        }
        users[msg.sender].totalEntriesPurchased += numEntries;
        users[msg.sender].cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        globalStats.totalEntriesPurchased += numEntries;

        _addToQueue(msg.sender);

        address userReferrer = users[msg.sender].referrer;
        if (userReferrer != address(0) && users[userReferrer].isActive) {
            uint256 totalBonus = numEntries * REFERRER_ENTRY_BONUS;
            _payReferralBonus(userReferrer, totalBonus);
        }

        _distributeTeamShares(numEntries);
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

    // ============ Governance Functions ============

    function initiateWithdrawal(address to, uint256 amount) external onlySigner returns (bytes32) {
        if (to == address(0)) revert KhoopDefi__ZeroAddress();
        if (amount == 0) revert KhoopDefi__InvalidAmount();

        bytes32 withdrawalId = keccak256(abi.encodePacked(to, amount, block.timestamp, block.prevrandao));

        Withdrawal storage newWithdrawal = withdrawals[withdrawalId];
        if (newWithdrawal.unlockTime != 0) revert KhoopDefi__WithdrawalAlreadyExecuted();

        newWithdrawal.to = to;
        newWithdrawal.amount = amount;
        newWithdrawal.unlockTime = block.timestamp + TIMELOCK_DURATION;
        newWithdrawal.confirmations = 1;
        newWithdrawal.executed = false;
        newWithdrawal.isConfirmed[msg.sender] = true;

        emit WithdrawalInitiated(withdrawalId, to, amount, newWithdrawal.unlockTime);
        emit WithdrawalConfirmed(withdrawalId, msg.sender);

        return withdrawalId;
    }

    function confirmWithdrawal(bytes32 withdrawalId) external onlySigner {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];

        if (withdrawal.unlockTime == 0) revert KhoopDefi__WithdrawalDoesNotExist();
        if (withdrawal.executed) revert KhoopDefi__WithdrawalAlreadyExecuted();
        if (withdrawal.isConfirmed[msg.sender]) revert KhoopDefi__AlreadyConfirmed();

        withdrawal.isConfirmed[msg.sender] = true;
        withdrawal.confirmations++;

        emit WithdrawalConfirmed(withdrawalId, msg.sender);

        if (withdrawal.confirmations >= requiredSignatures && block.timestamp >= withdrawal.unlockTime) {
            _executeWithdrawal(withdrawalId);
        }
    }

    function executeWithdrawal(bytes32 withdrawalId) external {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];

        if (withdrawal.unlockTime == 0) revert KhoopDefi__WithdrawalDoesNotExist();
        if (withdrawal.executed) revert KhoopDefi__WithdrawalAlreadyExecuted();
        if (withdrawal.confirmations < requiredSignatures) revert KhoopDefi__InsufficientConfirmations();
        if (block.timestamp < withdrawal.unlockTime) revert KhoopDefi__TimelockNotExpired();

        _executeWithdrawal(withdrawalId);
    }

    // ============ Internal Functions ============

    function _executeWithdrawal(bytes32 withdrawalId) internal {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];
        withdrawal.executed = true;

        usdt.safeTransfer(withdrawal.to, withdrawal.amount);

        emit WithdrawalExecuted(withdrawalId, withdrawal.to, withdrawal.amount);
    }

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

    function _addToQueue(address user) internal {
        UserRoundInfo storage info = userRoundInfo[user];

        if (!info.inQueue) {
            info.inQueue = true;
            _queueIndex[user] = queueOrder.length;
            queueOrder.push(user);
            emit UserAddedToQueue(user);
        }
    }

    function _removeFromQueue(address user) internal {
        UserRoundInfo storage info = userRoundInfo[user];
        info.inQueue = false;

        uint256 userIndex = _queueIndex[user];
        uint256 lastIndex = queueOrder.length - 1;

        if (userIndex != lastIndex) {
            // Move the last element to the deleted user's position
            address lastUser = queueOrder[lastIndex];
            queueOrder[userIndex] = lastUser;
            _queueIndex[lastUser] = userIndex;
        }

        // Remove the last element
        queueOrder.pop();
        delete _queueIndex[user];

        // Reset currentQueueIndex if queue is empty
        if (queueOrder.length == 0) {
            currentQueueIndex = 0;
        } else if (currentQueueIndex >= queueOrder.length) {
            currentQueueIndex = 0;
        }

        emit UserRemovedFromQueue(user);
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

        uint256 totalDistributed = (totalCorePerWallet * 4) + (totalInvestorPerWallet * 15) + totalContingency;
        emit TeamSharesDistributed(numEntries, totalDistributed);
    }

    /**
     * @notice Process cycles sequentially - STRICT FIFO
     * @dev Must complete slots in exact order, cannot skip
     */
    function _processAvailableCycles() internal returns (uint256 totalCyclesProcessed) {
        if (queueOrder.length == 0) return 0;

        uint256 totalPaid = 0;
        uint256 processedInThisRound = 0;
        uint256 currentIndex = currentQueueIndex;
        uint256 minGas = 50000;

        // Process while we have enough balance and gas
        while (
            queueOrder.length > 0 && usdt.balanceOf(address(this)) >= CYCLE_PAYOUT
                && processedInThisRound < queueOrder.length
        ) {
            if (gasleft() < minGas) revert KhoopDefi__GasLimitExceeded();

            address currentUser = queueOrder[currentIndex];
            (bool anyProcessed, uint256 paidAmount) = _processUserRound(currentUser);

            if (anyProcessed) {
                totalCyclesProcessed += (paidAmount / CYCLE_PAYOUT);
                totalPaid += paidAmount;
                processedInThisRound = 0; // Reset counter on successful process
            } else {
                processedInThisRound++; // Increment on failure
            }

            // Move to next user with bounds checking
            if (queueOrder.length > 0) {
                currentIndex = (currentIndex + 1) % queueOrder.length;

                // If we've gone full circle, check if we made progress
                if (currentIndex == currentQueueIndex) {
                    if (totalCyclesProcessed == 0) {
                        // No progress in a full cycle, break to avoid infinite loop
                        break;
                    }
                    // Reset for next round
                    processedInThisRound = 0;
                }
            } else {
                currentIndex = 0;
                break; // Exit loop if queue is empty
            }
        }

        // Update the global index for next time
        currentQueueIndex = currentIndex;

        if (totalCyclesProcessed > 0) {
            emit CyclesProcessed(totalCyclesProcessed, totalPaid);
        }

        return totalCyclesProcessed;
    }

    /**
     * @notice Process one cycle on ALL pending slots for a user in order
     * @dev Processes as many as possible until balance insufficient
     * @return anyProcessed Whether any cycles were completed
     * @return totalPaid Total amount paid (multiple of 5 USDT if successful)
     */
    function _processUserRound(address user) internal returns (bool anyProcessed, uint256 totalPaid) {
        uint256[] storage userSlots = userEntries[user];

        if (userSlots.length == 0) {
            _removeFromQueue(user);
            _updateUserActiveStatus(user);
            return (false, 0);
        }

        anyProcessed = false;
        totalPaid = 0;

        for (uint256 i = 0; i < userSlots.length; i++) {
            uint256 entryId = userSlots[i];
            Entry storage entry = entries[entryId];

            // Process this slot if it's active and not maxed out
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                // Check balance
                if (usdt.balanceOf(address(this)) < CYCLE_PAYOUT) {
                    break;
                }

                // Process this cycle
                entry.cyclesCompleted++;
                entry.lastCycleTimestamp = block.timestamp;

                // Update stats
                users[user].totalCyclesCompleted++;
                users[user].totalEarnings += CYCLE_PAYOUT;
                globalStats.totalCyclesCompleted++;
                globalStats.totalPayoutsMade += CYCLE_PAYOUT;

                // Check if entry maxed out
                if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
                    entry.isActive = false;
                    emit EntryMaxedOut(entryId, user);
                }

                // Send payout
                usdt.safeTransfer(user, CYCLE_PAYOUT);
                emit CycleCompleted(entryId, user, entry.cyclesCompleted, CYCLE_PAYOUT);

                anyProcessed = true;
                totalPaid += CYCLE_PAYOUT;
            }
        }

        // If we get here, update status
        _updateUserActiveStatus(user);

        if (!anyProcessed && !_hasPendingCycles(user)) {
            _removeFromQueue(user);
        }

        return (anyProcessed, totalPaid);
    }

    ///@dev Helper function to check if user has pending cycles
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

    ///@dev Internal function to update user active status
    function _updateUserActiveStatus(address user) internal {
        bool hasPending = _hasPendingCycles(user);
        if (users[user].isActive != hasPending) {
            users[user].isActive = hasPending;
            if (hasPending) {
                globalStats.totalActiveUsers += 1;
            } else {
                globalStats.totalActiveUsers -= 1;
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

    function getUserRoundInfo(address user) external view returns (bool inQueue) {
        UserRoundInfo storage info = userRoundInfo[user];
        return info.inQueue;
    }

    function getQueueOrder() external view returns (address[] memory) {
        return queueOrder;
    }

    function getCurrentQueueIndex() external view returns (uint256) {
        return currentQueueIndex;
    }

    function getQueueLength() external view returns (uint256) {
        return queueOrder.length;
    }

    function getNextInLine() external view returns (address user, uint256 totalSlots) {
        if (queueOrder.length == 0) {
            return (address(0), 0);
        }

        address nextUser = queueOrder[currentQueueIndex];

        return (nextUser, userEntries[nextUser].length);
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

    function getPendingCyclesCount() external view returns (uint256 count) {
        uint256 availableBalance = usdt.balanceOf(address(this));

        if (queueOrder.length == 0) return 0;

        uint256 tempIndex = currentQueueIndex;
        uint256 attempts = 0;
        uint256 maxAttempts = queueOrder.length * 100;
        uint256 simulatedPir = 0;

        while (availableBalance >= CYCLE_PAYOUT && simulatedPir < queueOrder.length && attempts < maxAttempts) {
            attempts++;

            address user = queueOrder[tempIndex];
            uint256[] memory userSlots = userEntries[user]; // view, so non-storage

            bool userProcessed = false;

            for (uint256 i = 0; i < userSlots.length; i++) {
                Entry storage entry = entries[userSlots[i]];
                if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY && availableBalance >= CYCLE_PAYOUT)
                {
                    count++;
                    availableBalance -= CYCLE_PAYOUT;
                    userProcessed = true;
                }
            }

            if (userProcessed) {
                simulatedPir = 0;
            } else {
                simulatedPir++;
            }

            tempIndex = (tempIndex + 1) % queueOrder.length;
        }

        return count;
    }

    function getWithdrawalDetails(bytes32 withdrawalId)
        external
        view
        returns (address to, uint256 amount, uint256 unlockTime, uint256 confirmations, bool executed)
    {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];
        return (withdrawal.to, withdrawal.amount, withdrawal.unlockTime, withdrawal.confirmations, withdrawal.executed);
    }

    function isConfirmedBySigner(bytes32 withdrawalId, address signer) external view returns (bool) {
        return withdrawals[withdrawalId].isConfirmed[signer];
    }

    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    function getRequiredSignatures() external view returns (uint256) {
        return requiredSignatures;
    }

    function userHasPendingCycles(address user) external view returns (bool) {
        return _hasPendingCycles(user);
    }
}
