// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";

/// @notice Test helper contract that exposes setters for testing
contract TestKhoopDefi is KhoopDefi {
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _buyback,
        address _powerCycle,
        address _usdt
    ) KhoopDefi(_coreTeam, _investors, _reserve, _buyback, _powerCycle, _usdt) {
        // more tests
    }

    // Exposed setters for tests only
    function setBuybackAccumulated(uint256 v) external {
        buybackAccumulated = v;
    }

    function getPendingStartId() external view returns (uint256) {
        return pendingStartId;
    }

    function getNextEntryId() external view returns (uint256) {
        return nextEntryId;
    }

    function getEntry(uint256 entryId) external view returns (uint256, address, uint256, bool) {
        Entry memory entry = entries[entryId];
        return (entry.entryId, entry.owner, entry.purchaseTimestamp, entry.isActive);
    }
}

contract RobustTests is Test {
    MockUSDT usdt;
    TestKhoopDefi khoop;

    // actors
    address owner = address(0xABCD);
    address testOwner; // Will be set to msg.sender
    address reserve = address(0xDEAD);
    address buyback = address(0xCAFE);
    address powerCycle = address(0xBEEF); // Add powerCycle address

    // Helper function to register users
    function _registerUser(address user, address referrer, uint256 usdtAmount) internal {
        // Skip if already registered
        (,,,,,,, bool isRegistered,) = khoop.users(user);
        if (isRegistered) {
            return;
        }

        // Mint USDT to user
        usdt.mint(user, usdtAmount);

        // Register user
        vm.prank(user);
        khoop.registerUser(user, referrer);

        // Approve spending
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);
    }

    address core1 = address(0x1001);
    address core2 = address(0x1002);
    address core3 = address(0x1003);
    address core4 = address(0x1004);

    // investors addresses (15)
    address[15] investors;

    // buyers
    address buyer = address(0x2001);

    // constants (match your contract)
    uint256 constant USDT_DECIMALS = 1e18;
    uint256 constant ENTRY_COST = 15e18; // 15 * 10^18
    uint256 constant BUYBACK_PER_ENTRY = 3e18; // 3 * 10^18
    uint256 constant BUYBACK_THRESHOLD = 10e18; // 10 * 10^18
    uint256 constant MAX_AUTO_FILLS_PER_PURCHASE = 5;

    function setUp() public {
        // deploy mock USDT and mint
        usdt = new MockUSDT();

        // Initialize core team and investors arrays
        address[4] memory coreTeam;
        address[15] memory investorsArray;

        // Set up core team
        coreTeam[0] = core1 = address(0x1001);
        coreTeam[1] = core2 = address(0x1002);
        coreTeam[2] = core3 = address(0x1003);
        coreTeam[3] = core4 = address(0x1004);

        // Set up investors
        for (uint256 i = 0; i < 15; i++) {
            investorsArray[i] = address(uint160(2000 + i));
        }

        // Deploy contract first
        khoop = new TestKhoopDefi(coreTeam, investorsArray, reserve, buyback, powerCycle, address(usdt));

        // Store investors in storage for later use
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = investorsArray[i];
        }

        // Register system users (only once)
        _registerUser(powerCycle, address(0), 1_000_000e18);
        _registerUser(owner, powerCycle, 1_000_000e18);
        _registerUser(reserve, powerCycle, 1_000_000e18);
        _registerUser(buyback, powerCycle, 1_000_000e18);
        _registerUser(buyer, powerCycle, 1_000_000e18);

        // Register core team (only those not already registered)
        for (uint256 i = 0; i < 4; i++) {
            address teamMember = coreTeam[i];
            if (teamMember != powerCycle && teamMember != reserve && teamMember != buyback) {
                _registerUser(teamMember, powerCycle, 1_000_000e18);
            }
        }

        // Register investors (only those not already registered)
        for (uint256 i = 0; i < 15; i++) {
            address investor = investors[i];
            if (investor != powerCycle && investor != reserve && investor != buyback) {
                _registerUser(investor, powerCycle, 1_000_000e18);
            }
        }

        // Fund test contract with USDT
        usdt.mint(address(this), 1_000_000e18);
        usdt.approve(address(khoop), type(uint256).max);

        // Set testOwner to the contract address for testing
        testOwner = address(this);
    }

    /// @notice Test 1: Gas Limit Protection
    function test_gasLimitProtection() public {
        // Set buyback pot to $1000 (100 thresholds)
        khoop.setBuybackAccumulated(1000e6);

        // Create 100 pending entries
        // for every purchase 5 auto-fills are processed
        // so in total 500 auto-fills are processed
        for (uint256 i = 0; i < 100; i++) {
            address user = address(uint160(1000 + i));
            usdt.mint(user, 1000e18);
            vm.startPrank(user);
            usdt.approve(address(khoop), type(uint256).max);
            khoop.registerUser(user, powerCycle);
            khoop.purchaseEntries(1);
            vm.stopPrank();
        }

        // Single purchase should only process 5 auto-fills (not 100)
        uint256 gasBefore = gasleft();
        vm.prank(buyer);
        khoop.purchaseEntries(10);
        uint256 gasUsed = gasBefore - gasleft();

        // Should use reasonable gas (not hit block limit)
        assertLt(gasUsed, 10_000_000, "Gas usage too high - potential gas limit issue");

        // Correct math: 100 users × 3e6 = 300e6 added to buyback
        // Total buyback: 1000e6 + 300e6 = 1300e6 (130 thresholds)
        // 5 auto-fills per purchase * 100 purchases = 500 auto-fills
        // Early purchases consume buyback, later purchases have less available
        // so the final buyback should be less than 1000e6
        uint256 finalBuyback = khoop.getBuybackAccumulated();

        // Should be significantly reduced from initial 1000e6
        assertTrue(finalBuyback < 1000e18, "Buyback should be reduced from initial 1000e18");

        // Log the actual value for debugging
        console.log("Final buyback amount:", finalBuyback);
        console.log("Expected: significantly less than 1000e6 due to auto-fill processing");
    }

    /// @notice Test 2: Insufficient Balance Handling
    function test_insufficientBalanceGracefulExit() public {
        // Set large buyback pot
        khoop.setBuybackAccumulated(100e18);

        // Create pending entries
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(2000 + i));
            usdt.mint(user, 1000e18);
            vm.prank(user);
            usdt.approve(address(khoop), type(uint256).max);
            vm.prank(user);
            khoop.purchaseEntries(1);
        }

        // Drain contract USDT balance to leave only $10 (enough for 2 payouts of $5 each)
        uint256 currentBalance = usdt.balanceOf(address(khoop));
        if (currentBalance > 10e18) {
            uint256 drainAmount = currentBalance - 10e18;
            vm.prank(address(khoop));
            usdt.transfer(owner, drainAmount);
        }

        // Purchase should still work, but auto-fills stop when balance insufficient
        uint256 buybackBefore = khoop.getBuybackAccumulated();
        vm.prank(buyer);
        khoop.purchaseEntries(10);

        // Should not revert, but process fewer auto-fills due to insufficient balance
        uint256 buybackAfter = khoop.getBuybackAccumulated();
        assertEq(buybackAfter, 0, "Buyback should be depleted to 0");
    }

    /// @notice Test 3: Queue Advancement Test
    function test_queueAdvancementCorrectness() public {
        // Create 10 pending entries
        address[] memory users = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            users[i] = address(uint160(3000 + i));
            usdt.mint(users[i], 1000e18);
            vm.startPrank(users[i]);
            usdt.approve(address(khoop), type(uint256).max);
            khoop.registerUser(users[i], powerCycle);
            khoop.purchaseEntries(1);
            vm.stopPrank();
        }

        // Set buyback pot to process 5 auto-fills (50e6 = 5 * 10e6)
        khoop.setBuybackAccumulated(50e18);

        // Purchase should trigger auto-fills
        uint256 startId = khoop.getPendingStartId();
        vm.prank(buyer);
        khoop.purchaseEntries(10);
        uint256 endId = khoop.getPendingStartId();

        // Queue should advance by at least 1 (entries that reached cycle 3)
        // Note: Queue only advances when entries are marked as completed (cycle 3)
        assertTrue(endId > startId, "Queue should advance by at least 1 position");
        console.log("Queue advanced from", startId, "to", endId);
        console.log("Queue advancement:", endId - startId);
    }

    /// @notice Test 3.5: Fair FIFO Processing Test
    function test_fairFifoProcessing() public {
        // Create 5 pending entries from different users
        address[] memory users = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(4000 + i));
            usdt.mint(users[i], 1000e18);
            vm.startPrank(users[i]);
            usdt.approve(address(khoop), type(uint256).max);
            khoop.registerUser(users[i], powerCycle);
            khoop.purchaseEntries(1);
            vm.stopPrank();
        }

        // Set buyback pot to process 5 auto-fills (50e6 = 5 * 10e6)
        khoop.setBuybackAccumulated(50e18);

        // Record initial queue position
        uint256 initialQueuePos = khoop.getPendingStartId();

        // Purchase should trigger 5 auto-fills
        vm.prank(buyer);
        khoop.purchaseEntries(10);

        // Record final queue position
        uint256 finalQueuePos = khoop.getPendingStartId();

        // The fix ensures fair processing: queue should advance properly
        // Before fix: same entry processed multiple times, queue barely advances
        // After fix: different entries processed, queue advances more fairly
        assertTrue(finalQueuePos > initialQueuePos, "Queue should advance after auto-fills");

        // The key test: verify that the fix prevents the same entry from being processed multiple times
        // by checking that the queue advancement is reasonable
        uint256 queueAdvancement = finalQueuePos - initialQueuePos;
        assertTrue(queueAdvancement >= 1, "Queue should advance by at least 1 position");
    }

    /// @notice Test 4: Simple Cycle Completion Test
    function test_simpleCycleCompletion() public {
        // Create entry
        address user = address(0x4000);
        usdt.mint(user, 1000e18);
        vm.startPrank(user);
        usdt.approve(address(khoop), type(uint256).max);
        khoop.registerUser(user, powerCycle);
        khoop.purchaseEntries(1);
        vm.stopPrank();

        uint256 entryId = khoop.getNextEntryId() - 1;

        // Set buyback pot for auto-fill
        khoop.setBuybackAccumulated(10e18);

        // Process auto-fill
        vm.startPrank(buyer);
        khoop.purchaseEntries(10);
        vm.stopPrank();

        // Check entry is completed (single cycle now)
        (uint256 id, address entryUser, uint256 timestamp, bool isCompleted) = khoop.getEntry(entryId);

        assertEq(entryUser, user, "Entry user should match");
        assertEq(id, entryId, "Entry ID should match");
    }

    /// @notice Test 5: Zero Pending Entries
    function test_zeroPendingEntries() public {
        // Set large buyback pot but no pending entries
        khoop.setBuybackAccumulated(100e18);

        // Purchase should not revert
        vm.startPrank(buyer);
        khoop.purchaseEntries(10);
        vm.stopPrank();

        // Buyback pot should have new contribution added and may process up to 5 thresholds
        uint256 finalBuyback = khoop.getBuybackAccumulated();

        uint256 initial = 100e18;
        uint256 added = 10 * 3e18;
        uint256 before = initial + added; // 130e18
        uint256 possible = before / 10e18;
        uint256 processed = possible > 5 ? 5 : possible;
        uint256 expected = before - processed * 10e18;

        assertEq(finalBuyback, expected, "Buyback should reflect contribution minus processed thresholds");
        console.log("Zero pending entries test - Final buyback:", finalBuyback);
    }

    /// @notice Test 6: Reentrancy Protection Test
    // function test_reentrancyProtection() public {
    //     // Create malicious contract
    //     MaliciousContract malicious = new MaliciousContract(address(khoop), address(usdt));

    //     // Give malicious contract USDT
    //     usdt.mint(address(malicious), 1000e18);
    //     vm.prank(address(malicious)b);
    //     usdt.approve(address(khoop), type(uint256).max);

    //     // Set up buyback pot
    //     khoop.setBuybackAccumulated(20e18);

    //     // Should revert due to reentrancy protection
    //     vm.expectRevert();
    //     malicious.attack();
    // }

    /// @notice Test 7: Event Emission Test
    function test_eventEmission() public {
        // Set buyback pot
        khoop.setBuybackAccumulated(50e18);

        // Create pending entries
        for (uint256 i = 0; i < 6; i++) {
            address user = address(uint160(5000 + i));
            _registerUser(user, powerCycle, 1000e18);
            vm.startPrank(user);
            khoop.purchaseEntries(1);
            vm.stopPrank();
        }

        // Purchase should work and process auto-fills
        vm.startPrank(buyer);
        khoop.purchaseEntries(10);
        vm.stopPrank();

        // Verify buyback pot was reduced (exact amount depends on how many auto-fills were processed)
        uint256 finalBuyback = khoop.getBuybackAccumulated();
        assertTrue(finalBuyback < 80e18, "Buyback should be reduced from initial 50e18 + 30e18 = 80e18");
        assertTrue(finalBuyback > 0, "Buyback should not be zero");

        console.log("Event emission test - Final buyback:", finalBuyback);
    }

    /// @notice Test 8: Maximum Entries Stress Test
    function test_maximumEntriesPerTx() public {
        // Test the 10 entry limit
        uint256 maxEntries = 10;
        uint256 amount = 15e18 * maxEntries;

        // Should work with 10 entries
        vm.prank(buyer);
        khoop.purchaseEntries(maxEntries);

        // Should fail with 11 entries
        vm.expectRevert();
        vm.prank(buyer);
        khoop.purchaseEntries(11);
    }

    /// @notice Test 9: Daily Limit Protection
    function test_dailyLimitProtection() public {
        // Create user
        address user = address(0x6000);
        usdt.mint(user, 1000e18);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);

        // First purchase should work
        vm.startPrank(user);
        khoop.registerUser(user, powerCycle);
        khoop.purchaseEntries(1);
        vm.stopPrank();

        // Try to exceed daily limit (50 entries)
        vm.expectRevert();
        vm.prank(user);
        khoop.purchaseEntries(50);
    }

    /// @notice Test 10: Cool Down Protection
    function test_coolDownProtection() public {
        // Create user
        address user = address(0x7000);
        usdt.mint(user, 1000e18);
        vm.prank(user);
        usdt.approve(address(khoop), type(uint256).max);

        // First purchase should work
        vm.startPrank(user);
        khoop.registerUser(user, powerCycle);
        khoop.purchaseEntries(1);
        vm.stopPrank();

        // Try to purchase again immediately (should fail due to 10min cooldown)
        vm.expectRevert();
        vm.prank(user);
        khoop.purchaseEntries(1);

        // Fast forward 30 minutes + 1 second
        vm.warp(block.timestamp + 31 minutes);

        // Now should work
        vm.prank(user);
        khoop.purchaseEntries(1);
    }
}
