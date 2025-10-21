// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";

contract KhoopDefiPaymentTests is Test {
    KhoopDefi public khoopDefi;
    MockUSDT public usdt;

    address[4] coreTeam;
    address[15] investors;
    address reserve;
    address powerCycle;

    uint256 constant SLOT_PRICE = 15e18;
    uint256 constant CYCLE_PAYOUT = 5e18;
    uint256 constant REFERRER_BONUS = 1e18;
    uint256 constant TEAM_SHARE_PER_PAYMENT = 1e18; // Simplified for testing

    address sponsor;
    address buyer;
    address donor;

    function setUp() public {
        usdt = new MockUSDT();

        // Setup wallets
        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = makeAddr(string(abi.encodePacked("core", i)));
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = makeAddr(string(abi.encodePacked("investor", i)));
        }
        reserve = makeAddr("reserve");
        powerCycle = makeAddr("powerCycle");

        khoopDefi = new KhoopDefi(coreTeam, investors, reserve, powerCycle, address(usdt));

        // Setup test users
        sponsor = makeAddr("sponsor");
        buyer = makeAddr("buyer");
        donor = makeAddr("donor");

        // Fund users
        usdt.mint(sponsor, 1000e18);
        usdt.mint(buyer, 1000e18);
        usdt.mint(donor, 10000e18);
    }

    function testBuyFiveSlots() public {
        // Create test users
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        address user5 = makeAddr("user5");

        // Register and buy slots for user1 (buys 1)
        _registerAndBuySlots(user1, powerCycle, 1);

        // User 2 should be reffered by user1
        vm.warp(block.timestamp + 10 minutes);
        _registerAndBuySlots(user2, user1, 10);

        // User 3 should be reffered by user2
        vm.warp(block.timestamp + 10 minutes);
        _registerAndBuySlots(user3, user2, 16);

        // User 4 should be reffered by user1
        vm.warp(block.timestamp + 10 minutes);
        _registerAndBuySlots(user4, user1, 10);

        (
            uint256 totalUsers,
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalRefferalBonusMissed,
            uint256 totalEarnings,
            uint256 totalCyclesCompleted,
            uint256 totalSlotsRemaining
        ) = khoopDefi.getGlobalStats();
        console.log("Total Users", totalUsers);
        console.log("Total Active Users", totalActiveUsers);
        console.log("Total Entries Purchased", totalEntriesPurchased);
        console.log("Total Referrer Bonus Paid", totalReferrerBonusPaid);
        console.log("Total Referrer Bonus Missed", totalRefferalBonusMissed);
        console.log("Total Earnings", totalEarnings);
        console.log("Total Cycles Completed", totalCyclesCompleted);
        console.log("Total Slots Remaining", totalSlotsRemaining);
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
        console.log("Team Accumulated Balance", khoopDefi.getTeamAccumulatedBalance() / 1e18);
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), 5000e18);
        khoopDefi.donateToSystem(5000e18);
        vm.stopPrank();

        // User 5 should be reffered by user1
        vm.warp(block.timestamp + 10 minutes);
        _registerAndBuySlots(user5, user1, 20);
        (,,, uint256 refferalBonusMisseds,,,) = khoopDefi.getUserStats(user1);
        (,,,, uint256 totalRefferalBonusMisseds,,,) = khoopDefi.getGlobalStats();
        (
            address owner,
            uint256 purchaseTimestamp,
            uint8 cyclesCompleted,
            uint256 lastCycleTimestamp,
            bool isActive,
            uint8 cycleRemaining
        ) = khoopDefi.getEntryDetails(1);
        console.log("Refferal Bonus Missed", refferalBonusMisseds / 1e18);
        console.log("Total Referrer Bonus Missed", totalRefferalBonusMisseds / 1e18);
        console.log("Owner", owner);
        console.log("Purchase Timestamp", purchaseTimestamp);
        console.log("Cycles Completed", cyclesCompleted);
        console.log("Last Cycle Timestamp", lastCycleTimestamp);
        console.log("Cycle Remaining", cycleRemaining);
        console.log("Active", isActive);
    }

    function testReferralBonusMissTracking() public {
        usdt.mint(address(khoopDefi), 100_000e18);
        address John = makeAddr("John");
        address Emeka = makeAddr("Emeka");

        _registerAndBuySlots(John, powerCycle, 1);
        (,,, uint256 totalRefferalBonusPaid1, uint256 totalRefferalBonusMissed1,,,) = khoopDefi.getGlobalStats();
        console.log("John active status after buying 1 slot is:", khoopDefi.userHasPendingCycles(John));
        console.log("total referral bonus paid is:", totalRefferalBonusPaid1 / 1e18);
        console.log("total referral bonus missed is:", totalRefferalBonusMissed1 / 1e18);
        // Powercycle gets $4 paid in bonus
        // John is inactive now should missed referral bonus
        _registerAndBuySlots(Emeka, John, 10);
        (,,, uint256 refferalBonusMissed,,,) = khoopDefi.getUserStats(John);
        console.log("John referral bonus missed is:", refferalBonusMissed / 1e18);
        (,,,, uint256 totalRefferalBonusMissed,,, uint256 slotRemianing) = khoopDefi.getGlobalStats();
        console.log("Total referral bonus missed is:", totalRefferalBonusMissed / 1e18);
        console.log("Slot remaining is:", slotRemianing);
    }

    function testGasHandling() public {
        uint256 initialGas = gasleft();
        console.log("Initial Gas", initialGas);
        for (uint256 i = 1; i < 100_001; i++) {
            vm.startPrank(address(uint160(i)));
            _registerAndBuySlots(address(uint160(i)), powerCycle, 10);
            vm.stopPrank();
        }
        console.log("Final Gas", gasleft());
        console.log("Gas used", initialGas - gasleft());
        console.log("Entry length", khoopDefi.getQueueLength());
    }

    function testRealisticDoSScenario() public {
        // Setup: Attacker fills queue
        address attacker = address(0x666);
        usdt.mint(attacker, 300_000e18); // Reduced to $300k USDT
        console.log("Starting gas", gasleft());

        vm.startPrank(attacker);
        usdt.approve(address(khoopDefi), 300_000e18);
        khoopDefi.registerUser(attacker, powerCycle);

        // Attacker buys entries in smaller batches
        uint256 totalEntries = 0;
        for (uint256 i = 0; i < 200; i++) {
            // Reduced from 500 to 50 (6000 entries)
            vm.warp(block.timestamp + 31 minutes);
            try khoopDefi.purchaseEntries(5) {
                totalEntries += 5;
            } catch {
                console.log("Failed at iteration", i);
                break;
            }
        }
        vm.stopPrank();
        console.log("After attacker makes purchase gas", gasleft());
        console.log("Queue length after attack:", khoopDefi.getQueueLength());
        console.log("Total entries created:", totalEntries);

        // Now try normal user purchase
        address victim = address(0x123);
        usdt.mint(victim, 100e18);

        vm.startPrank(victim);
        usdt.approve(address(khoopDefi), 100e18);
        khoopDefi.registerUser(victim, powerCycle);

        uint256 gasBefore = gasleft();
        try khoopDefi.purchaseEntries(1) {
            uint256 gasUsed = gasBefore - gasleft();
            console.log("Gas used by victim:", gasUsed);
            if (gasUsed > 10_000_000) {
                console.log(" DoS RISK: Excessive gas consumption");
            }
        } catch {
            console.log(" CRITICAL: Transaction reverted - DoS attack successful");
        }
        vm.stopPrank();

        // Batch processing test
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
        usdt.mint(address(khoopDefi), 100_000_000e18);
        uint256 pendingCyclesCount = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Before Count", pendingCyclesCount);
        uint256 startingGas = gasleft();
        console.log("Gas before cycles processing", startingGas);
        try khoopDefi.processCyclesBatch(pendingCyclesCount) {
            console.log("Batch processing successful");
        } catch {
            console.log("Batch processing failed");
        }
        uint256 pendingCyclesCountAfter = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter);
        console.log("Gas after cycles processing", gasleft());
        console.log("Gas used", startingGas - gasleft());
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
        try khoopDefi.processCyclesBatch(pendingCyclesCountAfter) {
            console.log("Batch processing successful");
        } catch {
            console.log("Batch processing failed");
        }
        uint256 pendingCyclesCountAfter2 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter2);
        console.log("Gas after cycles processing", gasleft());
        console.log("Gas used", startingGas - gasleft());
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
        try khoopDefi.processCyclesBatch(pendingCyclesCountAfter2) {
            console.log("Batch processing successful");
        } catch {
            console.log("Batch processing failed");
        }
        uint256 pendingCyclesCountAfter3 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter3);
        console.log("Gas after cycles processing", gasleft());
        console.log("Gas used", startingGas - gasleft());
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
        console.log("Average cycles processed", (pendingCyclesCount - pendingCyclesCountAfter3) / 3);
        vm.warp(block.timestamp + 1 hours);
        try khoopDefi.processCyclesBatch(pendingCyclesCountAfter3) {
            console.log("Batch processing successful");
        } catch {
            console.log("Batch processing failed");
        }
        uint256 pendingCyclesCountAfter4 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter4);
        console.log("Gas after cycles processing", gasleft());
        console.log("Gas used", startingGas - gasleft());
        console.log("Contract Balance", khoopDefi.getContractBalance() / 1e18);
    }

    function testCompleteCycle() public {
        address John = makeAddr("John");
        usdt.mint(John, 1000e18);
        vm.startPrank(John);
        _registerAndBuySlots(John, powerCycle, 10);
        vm.startPrank(John);
        khoopDefi.reduceCooldown();
        khoopDefi.reduceCooldown();
        khoopDefi.purchaseEntries(10);
        khoopDefi.reduceCooldown();
        khoopDefi.reduceCooldown();
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        assertEq(2e18, khoopDefi.getAccumulatedCoolDownFee());

        uint256 pendingCyclesCount = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count", pendingCyclesCount);
        usdt.mint(address(khoopDefi), 100_000e18);
        khoopDefi.completeCycles();
        uint256 pendingCyclesCountAfter2 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter2);
        khoopDefi.completeCycles();
        uint256 pendingCyclesCountAfter3 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter3);
        khoopDefi.completeCycles();
        uint256 pendingCyclesCountAfter4 = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count After", pendingCyclesCountAfter4);
    }

    function _registerAndBuySlots(address user, address referrer, uint256 numSlots) internal {
        // Fund user
        usdt.mint(user, 1000e18);

        // Start prank for this user
        vm.startPrank(user);

        // Register user with powerCycle as referrer
        khoopDefi.registerUser(user, referrer);

        // Approve KhoopDefi to spend user's USDT
        usdt.approve(address(khoopDefi), type(uint256).max);

        // Buy slots
        khoopDefi.purchaseEntries(numSlots);

        // Stop prank
        vm.stopPrank();
    }

    /// @notice Test 1: Verify payment at purchase (1/4)
    function testPaymentOnPurchase() public {
        // Register sponsor first
        vm.startPrank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1); // Sponsor buys 1 to become active
        vm.stopPrank();

        uint256 sponsorBalanceBefore = usdt.balanceOf(sponsor);
        uint256 coreTeamBalanceBefore = usdt.balanceOf(coreTeam[0]);

        // Register buyer with sponsor as referrer
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        uint256 sponsorBalanceAfter = usdt.balanceOf(sponsor);
        uint256 coreTeamBalanceAfter = usdt.balanceOf(coreTeam[0]);

        console.log("\n=== Payment 1/4: At Purchase ===");
        console.log("Sponsor earned:", (sponsorBalanceAfter - sponsorBalanceBefore) / 1e18);
        console.log("Core team member earned:", (coreTeamBalanceAfter - coreTeamBalanceBefore) / 1e18);

        // Verify sponsor got referral bonus
        assertGt(sponsorBalanceAfter, sponsorBalanceBefore, "Sponsor should earn at purchase");

        // Verify team got paid
        assertGt(coreTeamBalanceAfter, coreTeamBalanceBefore, "Team should earn at purchase");
    }

    /// @notice Test 2: Verify payments during cycles 1, 2, 3 (payments 2,3,4)
    function testPaymentsDuringCycles() public {
        console.log("KhoopDefi Balance before purchase 1", usdt.balanceOf(address(khoopDefi)) / 1e18);
        console.log("Sponsor balance before purchase 1", usdt.balanceOf(sponsor) / 1e18);
        vm.startPrank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        console.log("KhoopDefi Balance after purchase 1", usdt.balanceOf(address(khoopDefi)) / 1e18);
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1); // Entry ID 2
        vm.stopPrank();

        (,, uint8 cyclesCompleted,, bool isActive, uint8 cycleRemaining) = khoopDefi.getEntryDetails(1);
        console.log("Entry 1 cycles completed:", cyclesCompleted);
        console.log("Entry 1 is active:", isActive);
        console.log("Entry 1 cycle remaining:", cycleRemaining);

        (,, uint8 cyclesCompleted2,, bool isActive2, uint8 cycleRemaining2) = khoopDefi.getEntryDetails(2);
        console.log("Entry 2 cycles completed:", cyclesCompleted2);
        console.log("Entry 2 is active:", isActive2);
        console.log("Entry 2 cycle remaining:", cycleRemaining2);
        console.log("KhoopDefi Balance after purchase 2", usdt.balanceOf(address(khoopDefi)) / 1e18);
        console.log("Pending Cycles Count", khoopDefi.getPendingCyclesCount());

        // There are 5 cycles reaming to complete one cycle is 4+1+1
        // So donate 5 * 5e18 = 25e18

        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(30e18);
        vm.stopPrank();
        console.log("KhoopDefi Balance after donate", usdt.balanceOf(address(khoopDefi)) / 1e18);
        console.log("Pending Cycles Count after donation", khoopDefi.getPendingCyclesCount());
        console.log("Sponsor balance after cycles completed", usdt.balanceOf(sponsor) / 1e18);
        // $5 + $4
    }

    /// @notice Test 3: Inactive referrer doesn't earn
    function testInactiveReferrerNoEarnings() public {
        // Register sponsor but DON'T buy (inactive)
        vm.prank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);

        uint256 sponsorBalanceBefore = usdt.balanceOf(sponsor);

        // Buyer purchases with inactive sponsor
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        uint256 sponsorBalanceAfter = usdt.balanceOf(sponsor);

        console.log("\n=== Inactive Referrer Test ===");
        console.log("Sponsor is active:", khoopDefi.isUserActive(sponsor));
        console.log("Sponsor earned:", (sponsorBalanceAfter - sponsorBalanceBefore) / 1e18);
        // (,,, uint256 refferalBonusMissed2,,,) = khoopDefi.getUserStats(sponsor);
        (
            uint256 totalUsers,
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalRefferalBonusMissed,
            uint256 totalEarnings,
            uint256 totalCyclesCompleted,
            uint256 totalSlotsRemaining
        ) = khoopDefi.getGlobalStats();
        console.log("Total Referrer Bonus Missed", totalRefferalBonusMissed / 1e18);
        console.log("Total Users", totalUsers);
        console.log("Total Active Users", totalActiveUsers);
        console.log("Total Entries Purchased", totalEntriesPurchased);
        console.log("Total Referrer Bonus Paid", totalReferrerBonusPaid);
        console.log("Total Earnings", totalEarnings);
        console.log("Total Cycles Completed", totalCyclesCompleted);
        console.log("Total Slots Remaining", totalSlotsRemaining);

        assertEq(sponsorBalanceAfter, sponsorBalanceBefore, "Inactive sponsor should earn nothing");

        // Okay let sponspor be atice buy slots and get in active again
        vm.startPrank(sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 minutes);
        vm.startPrank(buyer);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(1000e18);
        vm.stopPrank();

        uint256 sponsorBalanceAfter2 = usdt.balanceOf(sponsor);

        console.log("\n=== Active Referrer Test ===");
        console.log("Sponsor is active:", khoopDefi.isUserActive(sponsor));
        console.log("Sponsor earned:", (sponsorBalanceAfter2 - sponsorBalanceAfter) / 1e18);
        (uint256 totalEntryPurchased, uint256 totalCyclesCompleteddd,, uint256 refferalBonusMissed2,,,) =
            khoopDefi.getUserStats(sponsor);
        (
            uint256 totalUsers2,
            uint256 totalActiveUsers2,
            uint256 totalEntriesPurchased2,
            uint256 totalReferrerBonusPaid2,
            uint256 totalRefferalBonusMissed2,
            uint256 totalEarnings2,
            uint256 totalCyclesCompleted2,
            uint256 totalSlotsRemaining2
        ) = khoopDefi.getGlobalStats();
        console.log("Total Entry purchased", totalEntryPurchased);
        console.log("Refferal Bonus Missed", refferalBonusMissed2 / 1e18);
        console.log("Total Cycles Completed", totalCyclesCompleteddd / 1e18);
        console.log("Total Referrer Bonus Missed", totalRefferalBonusMissed2 / 1e18);
        console.log("Total Users", totalUsers2);
        console.log("Total Active Users", totalActiveUsers2);
        console.log("Total Entries Purchased", totalEntriesPurchased2);
        console.log("Total Referrer Bonus Paid", totalReferrerBonusPaid2);
        console.log("Total Earnings", totalEarnings2);
        console.log("Total Cycles Completed", totalCyclesCompleted2);
        console.log("Total Slots Remaining", totalSlotsRemaining2);
    }

    /// @notice Test 4: Verify total payments = 4 per slot
    function testTotalPaymentsPerSlot() public {
        // Setup active sponsor
        vm.startPrank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        uint256 sponsorBalanceBefore = usdt.balanceOf(sponsor);

        // Buyer purchases 1 slot
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        // Process all 4 cycles
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(100e18); // Enough for all cycles
        vm.stopPrank();

        uint256 sponsorBalanceAfter = usdt.balanceOf(sponsor);
        uint256 totalSponsorEarnings = sponsorBalanceAfter - sponsorBalanceBefore;

        console.log("\n=== Total Payments Per Slot ===");
        console.log("Sponsor total earnings:", totalSponsorEarnings / 1e18);
        console.log("Expected (4 payments x $1):");

        // Verify exactly 4 payments
        assertEq(totalSponsorEarnings, 4 * REFERRER_BONUS, "Sponsor should earn exactly 4x referral bonus");

        // Verify user stats
        (,, uint256 referrerBonusEarned,,,,) = khoopDefi.getUserStats(sponsor);
        assertEq(referrerBonusEarned, 4 * REFERRER_BONUS, "User stats should show 4 bonuses");
    }

    /// @notice Test 5: ConsecutiveSkips prevents infinite loop
    function testConsecutiveSkipsExitCondition() public {
        // Register user and max out entry
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        // Process all cycles to max out entry
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(100e18);
        vm.stopPrank();

        // Verify entry is maxed out
        (,,,, bool isActive,) = khoopDefi.getEntryDetails(1);
        assertEq(isActive, false, "Entry should be maxed out");

        console.log("\n=== Testing ConsecutiveSkips ===");
        console.log("All entries maxed out, attempting to process cycles...");

        // Try to process cycles - should exit gracefully (no infinite loop)
        vm.expectRevert(KhoopDefi.KhoopDefi__NoActiveCycles.selector);
        khoopDefi.completeCycles();

        console.log("Successfully exited without infinite loop!");
    }

    /// @notice Test 6: Multiple slots, verify cap per slot
    function testMultipleSlotsPaymentCap() public {
        // Setup active sponsor
        vm.startPrank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        uint256 sponsorBalanceBefore = usdt.balanceOf(sponsor);

        // Buyer purchases 3 slots
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(3);
        vm.stopPrank();

        // Process all cycles
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(500e18);
        vm.stopPrank();

        uint256 sponsorBalanceAfter = usdt.balanceOf(sponsor);
        uint256 totalSponsorEarnings = sponsorBalanceAfter - sponsorBalanceBefore;

        console.log("\n=== Multiple Slots Payment Cap ===");
        console.log("Slots purchased: 3");
        console.log("Sponsor total earnings:", totalSponsorEarnings / 1e18);
        console.log("Expected (3 slots x 4 payments x $1): 12");

        // 3 slots x 4 payments each = 12 USDT
        assertEq(totalSponsorEarnings, 3 * 4 * REFERRER_BONUS, "Should earn 4x per slot");
    }

    /// @notice Test 7: Slots remaining tracking
    function testSlotsRemainingTracking() public {
        console.log("\n=== Slots Remaining Tracking ===");

        // Initial state
        uint256 initialSlotsRemaining = khoopDefi.getPendingCyclesCount();
        console.log("Initial slots remaining:", initialSlotsRemaining);
        assertEq(initialSlotsRemaining, 0, "Should start with 0 slots");

        // User buys 2 slots (each has 4 cycles = 8 total slots)
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(2);
        vm.stopPrank();

        uint256 afterPurchaseSlotsRemaining = khoopDefi.getPendingCyclesCount();
        console.log("After 2 purchases:", afterPurchaseSlotsRemaining);
        assertEq(afterPurchaseSlotsRemaining, 8, "Should have 8 slots (2 entries x 4 cycles)");

        // Process 3 cycles
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(50e18);
        vm.stopPrank();

        uint256 afterProcessingSlotsRemaining = khoopDefi.getPendingCyclesCount();
        console.log("After processing some cycles:", afterProcessingSlotsRemaining);
        assertLt(afterProcessingSlotsRemaining, afterPurchaseSlotsRemaining, "Should decrease after processing");

        // Process all remaining
        vm.prank(donor);
        khoopDefi.donateToSystem(500e18);

        uint256 finalSlotsRemaining = khoopDefi.getPendingCyclesCount();
        console.log("After all cycles complete:", finalSlotsRemaining);
        assertEq(finalSlotsRemaining, 0, "Should have 0 slots remaining");
    }

    /// @notice Test 8: Sponsor becomes inactive mid-cycle
    function testSponsorBecomesInactive() public {
        // Sponsor buys 1 slot (will max out after 4 cycles)
        vm.startPrank(sponsor);
        khoopDefi.registerUser(sponsor, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        // Buyer purchases with active sponsor
        vm.startPrank(buyer);
        khoopDefi.registerUser(buyer, sponsor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(1);
        vm.stopPrank();

        console.log("\n=== Sponsor Becomes Inactive Test ===");
        console.log("Sponsor active:", khoopDefi.isUserActive(sponsor));

        // Process enough cycles to max out sponsor's entry
        vm.startPrank(donor);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.donateToSystem(100e18);
        vm.stopPrank();

        console.log("After processing, sponsor active:", khoopDefi.isUserActive(sponsor));

        uint256 sponsorBalanceBefore = usdt.balanceOf(sponsor);

        // Process buyer's remaining cycles (sponsor now inactive)
        vm.prank(donor);
        khoopDefi.donateToSystem(50e18);

        uint256 sponsorEarnings = usdt.balanceOf(sponsor) - sponsorBalanceBefore;
        console.log("Sponsor earnings while inactive:", sponsorEarnings / 1e18);

        assertEq(sponsorEarnings, 0, "Inactive sponsor should not earn");
    }
}
