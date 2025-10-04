// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";

contract KhoopDefiTest is Test {
    KhoopDefi public khoopDefi;
    MockUSDT public usdt;

    address[4] coreTeam;
    address[15] investors;
    address reserve;
    address buyback;
    address powerCycle;

    uint256 public constant SLOT_PRICE = 15e18;
    uint256 public constant USDT_DECIMALS = 10 ** 18;
    address user = makeAddr("user");

    function setUp() public {
        usdt = new MockUSDT();

        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = address(this);
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(this);
        }
        reserve = address(this);
        buyback = address(this);
        powerCycle = address(this);

        khoopDefi = new KhoopDefi(coreTeam, investors, reserve, buyback, powerCycle, address(usdt));
        usdt.mint(user, 1000e18);
        usdt.mint(address(khoopDefi), 10e18);
    }

    function _prepareUsers(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            address user = address(uint160(10000 + i));
            usdt.mint(user, 1000e18);
            vm.startPrank(user);
            usdt.approve(address(khoopDefi), SLOT_PRICE * 11);
            vm.stopPrank();
        }
    }

    function testPurchaseEntries() public {
        uint256 numOfUsers = 100000;
        _prepareUsers(numOfUsers);
        uint256 totalGas;
        uint256 maxGas;
        for (uint256 i = 0; i < numOfUsers; i++) {
            address user = address(uint160(10000 + i));
            // Use powerCycle as referrer for new users (first purchase)
            address refferer = powerCycle;
            vm.startPrank(user);
            uint256 beforeGas = gasleft();
            khoopDefi.purchaseEntries(10, refferer);
            uint256 used = beforeGas - gasleft();
            totalGas += used;
            if (used > maxGas) maxGas = used;
            if ((i + 1) % 100 == 0) {
                console.log("purchases", i + 1);
                console.log("last_purchase_gas", used);
            }
            vm.stopPrank();
        }
        console.log("total_purchase_gas", totalGas);
        console.log("max_purchase_gas", maxGas);
    }

    function testReduceCooldown() public {
        vm.startPrank(user);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(5, powerCycle);

        vm.expectRevert(KhoopDefi.KhoopDefi__InCooldown.selector);
        khoopDefi.purchaseEntries(20, powerCycle);

        khoopDefi.reduceCooldown();

        // Cooldown should be 15mins now
        vm.warp(block.timestamp + 15 minutes + 1);
        khoopDefi.purchaseEntries(5, powerCycle);

        vm.stopPrank();
    }

    function testReduceCooldownBelowFifteenMinutes() public {
        vm.startPrank(user);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(5, powerCycle);

        // Advance 20 mins in the future
        vm.warp(block.timestamp + 20 minutes);

        // reduce by 15mins meaning the user should be able to buy slot immediately
        khoopDefi.reduceCooldown();

        khoopDefi.purchaseEntries(5, powerCycle);

        vm.stopPrank();
    }

    function testProtocolPaysOldestEntry() public {
        // drain the contract but leave $1 for refferal payment
        uint256 contractBalance = usdt.balanceOf(address(khoopDefi)) - 1e18;
        vm.prank(address(khoopDefi));
        usdt.transfer(address(usdt), contractBalance);

        vm.startPrank(user);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(5, powerCycle);
        vm.stopPrank();

        (uint256 entryId, address owner, uint8 cyclesCompleted, bool isActive) = khoopDefi.getNextInLine();
        console.log("entryId", entryId);
        console.log("owner", owner);
        console.log("cyclesCompleted", cyclesCompleted);
        console.log("isActive", isActive);
        console.log("khoop defi remaining balance", usdt.balanceOf(address(khoopDefi)));

        // now we fund khoopDefi and the user calls complete cycle
        usdt.mint(address(khoopDefi), 100e18);
        vm.warp(block.timestamp + 30 minutes + 1);
        vm.prank(user);
        khoopDefi.purchaseEntries(5, powerCycle);
        vm.stopPrank();

        (uint256 entryId2, address owner2, uint8 cyclesCompleted2, bool isActive2) = khoopDefi.getNextInLine();
        console.log("entryId", entryId2);
        console.log("owner", owner2);
        console.log("cyclesCompleted", cyclesCompleted2);
        console.log("isActive", isActive2);
        console.log("khoop defi remaining balance", usdt.balanceOf(address(khoopDefi)));
    }

    function testRevertsIfUserTryToReduceCooldownWhenCooldownNotActive() public {
        vm.startPrank(user);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(5, powerCycle);

        // Advance 35 mins in the future
        vm.warp(block.timestamp + 35 minutes);

        // reduce by 15mins meaning the user should be able to buy slot immediately
        vm.expectRevert(KhoopDefi.KhoopDefi__CooldownNotActive.selector);
        khoopDefi.reduceCooldown();

        vm.stopPrank();
    }

    function testReferralBonusPerEntry() public {
        address user1 = address(0x1001);
        address user2 = address(0x1002);
        uint256 numEntries = 5; 
        uint256 perEntryBonus = 1e18; // $1 per entry
        uint256 expectedBonus = numEntries * perEntryBonus; // 5 * $1 = $5

        // Fund user1 1000usdt
        usdt.mint(user1, 1000e18);
        usdt.mint(user2, 1000e18);

        // Approve spending
        vm.startPrank(user1);
        usdt.approve(address(khoopDefi), type(uint256).max);

        khoopDefi.purchaseEntries(numEntries, powerCycle);
        vm.stopPrank();

        vm.startPrank(user2);
        usdt.approve(address(khoopDefi), type(uint256).max);

        uint256 reffererBalanceBefore = usdt.balanceOf(user1);
        (,,, uint256 bonusBefore,,,,) = khoopDefi.users(user1);
        khoopDefi.purchaseEntries(numEntries, user1);
        vm.stopPrank();

        uint256 reffererBalanceAfter = usdt.balanceOf(user1);
        // Check user1's stats after
        (,,, uint256 bonusAfter,,,,) = khoopDefi.users(user1);
        console.log("Bonus after:", bonusAfter / 1e18, "USDT");
        console.log("Bonus received:", (bonusAfter - bonusBefore) / 1e18, "USDT");

        // Should be 5 USDT (1 per entry)
        assertEq(bonusAfter - bonusBefore, expectedBonus, "Incorrect referral bonus");
    }

    function testReferralBonusSystem() public {
        // Setup users
        address referrer = address(uint160(5000));
        address user1 = address(uint160(10001));

        // Give USDT to users
        usdt.mint(referrer, 1000e18);
        usdt.mint(user1, 1000e18);

        // Register referrer first
        vm.startPrank(referrer);
        usdt.approve(address(khoopDefi), SLOT_PRICE);
        khoopDefi.purchaseEntries(1, powerCycle);
        vm.stopPrank();

        // User1 purchases with referrer
        vm.startPrank(user1);
        usdt.approve(address(khoopDefi), SLOT_PRICE);
        uint256 referrerBalanceBefore = usdt.balanceOf(referrer);
        khoopDefi.purchaseEntries(1, referrer);
        uint256 referrerBalanceAfter = usdt.balanceOf(referrer);
        vm.stopPrank();

        uint256 expectedBonus = 1e18;
        assertEq(referrerBalanceAfter - referrerBalanceBefore, expectedBonus, "Referral bonus should be $1");

        console.log("Referrer bonus received:", (referrerBalanceAfter - referrerBalanceBefore) / 1e6);
    }

    function testBuybackAutoFillMechanism() public {
        // Test buyback accumulation and auto-fill functionality
        uint256 buybackThreshold = 10e18; // $10 threshold (CORRECT!)
        uint256 entriesNeeded = 4; // Since $3 per entry, need 4 entries to reach $12 > $10

        _prepareUsers(entriesNeeded + 5);

        // Track buyback accumulation - make 3 purchases first (should be $9, below threshold)
        for (uint256 i = 0; i < 3; i++) {
            address user = address(uint160(10000 + i));
            vm.startPrank(user);
            khoopDefi.purchaseEntries(1, powerCycle);
            vm.stopPrank();
        }

        uint256 buybackBefore = khoopDefi.getBuybackAccumulated();
        console.log("Buyback after 3 purchases:", buybackBefore / 1e18); // Should be $9

        // This 4th purchase should trigger auto-fill (will reach $12)
        address triggerUser = address(uint160(10000 + 3));
        vm.startPrank(triggerUser);
        khoopDefi.purchaseEntries(1, powerCycle);
        vm.stopPrank();

        uint256 buybackAfter = khoopDefi.getBuybackAccumulated();
        console.log("Buyback after auto-fill:", buybackAfter / 1e18); // Should be $2 ($12 - $10)

        // Buyback should be reduced by threshold amount ($10)
        assertEq(
            buybackAfter, buybackBefore + 3e18 - buybackThreshold, "Buyback should decrease by $10 after auto-fill"
        );
    }

    function testCycleCompletion() public {
        // Test that users receive payouts when cycles complete
        address testUser = address(uint160(20000));
        usdt.mint(testUser, 1000e18);

        vm.startPrank(testUser);
        usdt.approve(address(khoopDefi), SLOT_PRICE);
        uint256 balanceBefore = usdt.balanceOf(testUser);
        khoopDefi.purchaseEntries(1, powerCycle);
        vm.stopPrank();

        // Simulate cycle completion by triggering buyback auto-fill
        uint256 buybackThreshold = 10e18; // CORRECT: $10 threshold
        uint256 entriesNeeded = 4; // Need 4 entries ($3 each = $12) to trigger $10 threshold
        _prepareUsers(entriesNeeded);

        for (uint256 i = 0; i < entriesNeeded; i++) {
            address user = address(uint160(10000 + i)); // FIXED: Use same range as _prepareUsers
            vm.startPrank(user);
            usdt.approve(address(khoopDefi), SLOT_PRICE);
            khoopDefi.purchaseEntries(1, powerCycle);
            vm.stopPrank();
        }

        uint256 balanceAfter = usdt.balanceOf(testUser);
        console.log("User balance before:", balanceBefore / 1e18);
        console.log("User balance after:", balanceAfter / 1e18);
        console.log("User balance change:", int256(balanceAfter) - int256(balanceBefore));

        // Check if user received payout (should be $5 profit only)
        // User spent $15 but received $5, so net change should be -$10
        // The user should have received $5 profit, so their balance should be:
        // Original balance - $15 (spent) + $5 (received) = Original balance - $10
        assertEq(balanceAfter, balanceBefore - 10e18, "User should have net -$10 change");
    }

    function testErrorConditions() public {
        address testUser = address(uint160(100000));

        // Test insufficient USDT
        vm.startPrank(testUser);
        vm.expectRevert();
        khoopDefi.purchaseEntries(1, powerCycle);
        vm.stopPrank();

        // Test invalid referrer (self-referral)
        usdt.mint(testUser, 1000e6);
        vm.startPrank(testUser);
        usdt.approve(address(khoopDefi), SLOT_PRICE);
        vm.expectRevert();
        khoopDefi.purchaseEntries(1, testUser); // Self-referral should fail
        vm.stopPrank();

        console.log("Error conditions tested successfully");
    }

    function testGasEfficiencyWithPendingStartId() public {
        // Test the gas efficiency improvement mentioned in memory about pendingStartId helpers
        uint256 numUsers = 1000;
        _prepareUsers(numUsers);

        uint256 totalGas = 0;
        uint256 maxGas = 0;

        // Purchase entries and measure gas for buyback auto-fill
        for (uint256 i = 0; i < numUsers; i++) {
            address user = address(uint160(10000 + i)); // Use same addresses as _prepareUsers
            vm.startPrank(user);

            uint256 gasBefore = gasleft();
            khoopDefi.purchaseEntries(1, powerCycle);
            uint256 gasUsed = gasBefore - gasleft();

            totalGas += gasUsed;
            if (gasUsed > maxGas) maxGas = gasUsed;

            if ((i + 1) % 100 == 0) {
                console.log("Entries processed:", i + 1);
                console.log("Last gas used:", gasUsed);
                console.log("Buyback accumulated:", khoopDefi.getBuybackAccumulated());
            }

            vm.stopPrank();
        }

        console.log("Average gas per purchase:", totalGas / numUsers);
        console.log("Max gas used:", maxGas);
        console.log("Total buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e6);
    }

    function testViewFunctions() public {
        // Test all view functions using the tuple-returning getGlobalStats
        (
            uint256 totalUsers,
            uint256 totalEntriesPurchaseds,
            uint256 totalReffererBonusPaid,
            uint256 totalSlotFillPaid,
            uint256 totalEntriesCompleted
        ) = khoopDefi.getGlobalStats();

        console.log("Global stats - total entries:", totalEntriesPurchaseds);
        console.log("Global stats - total users:", totalUsers);
        console.log("Global stats - total referrer bonus paid:", totalReffererBonusPaid / 1e18);
        console.log("Global stats - total slot fill paid:", totalSlotFillPaid / 1e18);
        console.log("Global stats - total entries completed:", totalEntriesCompleted);
        console.log("Next entry ID:", khoopDefi.nextEntryId());
        console.log("Buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e18);

        // Test user stats after purchase
        address testUser = address(uint160(120000));
        usdt.mint(testUser, 1000e18);

        vm.startPrank(testUser);
        usdt.approve(address(khoopDefi), SLOT_PRICE);
        khoopDefi.purchaseEntries(1, powerCycle);
        vm.stopPrank();

        // Check user data
        (
            address referrer,
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 totalEarnings,
            uint256 totalReferrals,
            uint256 lastEntryAt,
            bool isRegistered
        ) = khoopDefi.users(testUser);

        console.log("User entries purchased:", totalEntriesPurchased);
        console.log("User is registered:", isRegistered);
        console.log("User referrer:", referrer);
    }

    function testTeamDistribution() public {
        // Test that team distributions happen correctly
        _prepareUsers(10);

        uint256 contractBalanceBefore = usdt.balanceOf(address(khoopDefi));
        uint256 coreTeamBalanceBefore = usdt.balanceOf(coreTeam[0]);
        uint256 investorBalanceBefore = usdt.balanceOf(investors[0]);
        uint256 reserveBalanceBefore = usdt.balanceOf(reserve);

        // Make some purchases
        for (uint256 i = 0; i < 5; i++) {
            address user = address(uint160(10000 + i));
            vm.startPrank(user);
            khoopDefi.purchaseEntries(1, powerCycle);
            vm.stopPrank();
        }

        uint256 contractBalanceAfter = usdt.balanceOf(address(khoopDefi));
        uint256 coreTeamBalanceAfter = usdt.balanceOf(coreTeam[0]);
        uint256 investorBalanceAfter = usdt.balanceOf(investors[0]);
        uint256 reserveBalanceAfter = usdt.balanceOf(reserve);

        console.log("Contract balance change:", (contractBalanceAfter - contractBalanceBefore) / 1e6);
        console.log("Core team balance change:", (coreTeamBalanceAfter - coreTeamBalanceBefore) / 1e6);
        console.log("Investor balance change:", (investorBalanceAfter - investorBalanceBefore) / 1e6);
        console.log("Reserve balance change:", (reserveBalanceAfter - reserveBalanceBefore) / 1e6);
        console.log("Buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e6);

        // Team distribution should happen immediately on each purchase
        assertTrue(coreTeamBalanceAfter > coreTeamBalanceBefore, "Core team should receive distributions");
        assertTrue(investorBalanceAfter > investorBalanceBefore, "Investors should receive distributions");
        assertTrue(reserveBalanceAfter > reserveBalanceBefore, "Reserve should receive distributions");
    }
}
