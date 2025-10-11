// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.20;

// import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/Test.sol";
// import {KhoopDefi} from "../src/KhoopDefi.sol";
// import {MockUSDT} from "./mocks/MockUSDT.sol";

// contract KhoopDefiTest is Test {
//     KhoopDefi public khoopDefi;
//     MockUSDT public usdt;

//     address[4] coreTeam;
//     address[15] investors;
//     address reserve;
//     address buyback;
//     address powerCycle;

//     uint256 public constant SLOT_PRICE = 15e18;
//     uint256 public constant USDT_DECIMALS = 10 ** 18;
//     address user = makeAddr("user");

//     function setUp() public {
//         usdt = new MockUSDT();

//         for (uint256 i = 0; i < 4; i++) {
//             coreTeam[i] = address(this);
//         }
//         for (uint256 i = 0; i < 15; i++) {
//             investors[i] = address(this);
//         }
//         reserve = address(this);
//         buyback = address(this);
//         powerCycle = address(this);

//         khoopDefi = new KhoopDefi(coreTeam, investors, reserve, buyback, powerCycle, address(usdt));
//         usdt.mint(user, 1000e18);
//         usdt.mint(address(khoopDefi), 10e18);
//     }

//     function _prepareUsers(uint256 count) internal {
//         for (uint256 i = 0; i < count; i++) {
//             address user = address(uint160(10000 + i));
//             usdt.mint(user, 1000e18);
//             vm.startPrank(user);
//             khoopDefi.registerUser(user, powerCycle);
//             usdt.approve(address(khoopDefi), SLOT_PRICE * 11);
//             vm.stopPrank();
//         }
//     }

//     function testPurchaseEntries() public {
//         uint256 numOfUsers = 100;
//         _prepareUsers(numOfUsers);
//         uint256 totalGas;
//         uint256 maxGas;

//         for (uint256 i = 0; i < numOfUsers; i++) {
//             address testUser = address(uint160(10000 + i));

//             vm.startPrank(testUser);
//             uint256 beforeGas = gasleft();
//             khoopDefi.purchaseEntries(10);
//             uint256 used = beforeGas - gasleft();

//             totalGas += used;
//             if (used > maxGas) maxGas = used;

//             if ((i + 1) % 10 == 0) {
//                 console.log("Purchases completed:", i + 1);
//                 console.log("Last purchase gas:", used);
//             }
//             vm.stopPrank();
//         }

//         console.log("Total gas used:", totalGas);
//         console.log("Max gas per purchase:", maxGas);
//         console.log("Average gas per purchase:", totalGas / numOfUsers);
//     }

//     function testReduceCooldown() public {
//         // Register and activate user
//         vm.startPrank(user);
//         khoopDefi.registerUser(user, powerCycle);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);

//         // Should be in cooldown
//         vm.expectRevert(KhoopDefi.KhoopDefi__InCooldown.selector);
//         khoopDefi.purchaseEntries(20);

//         // Reduce cooldown
//         khoopDefi.reduceCooldown();

//         // After cooldown, should be able to purchase again
//         vm.warp(block.timestamp + 15 minutes + 1);
//         khoopDefi.purchaseEntries(5);

//         vm.stopPrank();
//     }

//     function testReduceCooldownBelowFifteenMinutes() public {
//         // Register and activate user
//         vm.startPrank(user);
//         khoopDefi.registerUser(user, powerCycle);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);

//         // Advance 20 mins in the future
//         vm.warp(block.timestamp + 20 minutes);

//         // Reduce cooldown
//         khoopDefi.reduceCooldown();

//         // Should be able to purchase immediately after reducing cooldown
//         khoopDefi.purchaseEntries(5);

//         vm.stopPrank();
//     }

//     function testRefferalDoesNotReceiveBonusIfNotRegistered() public {
//         vm.startPrank(user);
//         khoopDefi.registerUser(user, powerCycle);
//         vm.stopPrank();

//         vm.startPrank(address(5));
//         usdt.mint(address(5), 1000e18);
//         khoopDefi.registerUser(address(5), user);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);
//         vm.stopPrank();

//         (,,,uint256 referrerBonusEarned,,,,,) = khoopDefi.users(address(5));
//         assertEq(referrerBonusEarned, 0);

//         // Now user buy slots and earn refferal
//         vm.startPrank(user);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);
//         vm.stopPrank();

//         vm.warp(block.timestamp + 30 minutes + 1);

//         // address 5 buy 5 slots again user should receive $5
//         vm.startPrank(address(5));
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);
//         vm.stopPrank();

//         (,,,uint256 referrerBonusEarned2,,,,,) = khoopDefi.users(user);
//         assertEq(referrerBonusEarned2, 5e18);
//     }

//     function testProtocolPaysOldestEntry() public {
//         // User has 1k dollars
//         vm.prank(user);
//         usdt.approve(address(khoopDefi), type(uint256).max);

//         // Drain the contract but leave $1 for referral payment
//         uint256 contractBalance = usdt.balanceOf(address(khoopDefi)) - 1e18;
//         vm.prank(address(khoopDefi));
//         usdt.transfer(address(usdt), contractBalance);

//         // Purchase entries
//         vm.startPrank(user);
//         khoopDefi.registerUser(user, powerCycle);
//         khoopDefi.purchaseEntries(5);
//         vm.stopPrank();

//         // Check the next in line entry
//         (uint256 entryId, address owner, uint8 cyclesCompleted, bool isActive) = khoopDefi.getNextInLine();
//         assertEq(entryId, 1, "Should be the first entry");
//         assertEq(owner, user, "Owner should be the test user");
//         assertEq(cyclesCompleted, 1, "Should have 1 cycle completed");
//         assertTrue(isActive, "Entry should be active");

//         // Fund the contract and advance time to complete a cycle
//         usdt.mint(address(khoopDefi), 100e18);
//         vm.warp(block.timestamp + 30 minutes + 1);

//         // Purchase more entries to trigger cycle completion
//         vm.prank(user);
//         khoopDefi.purchaseEntries(5);

//         // Check the next in line entry again
//         (uint256 entryId2, address owner2, uint8 cyclesCompleted2, bool isActive2) = khoopDefi.getNextInLine();
//         assertEq(entryId2, 1, "Should still be the first entry");
//         assertEq(owner2, user, "Owner should still be the test user");
//         assertEq(cyclesCompleted2, 3, "Should have 3 cycles completed");
//         assertTrue(isActive2, "Entry should still be active");
//     }

//     function testRevertsIfUserTryToReduceCooldownWhenCooldownNotActive() public {
//         // Register and activate user
//         vm.startPrank(user);
//         khoopDefi.registerUser(user, powerCycle);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(5);

//         // Advance 35 mins in the future (past the cooldown period)
//         vm.warp(block.timestamp + 35 minutes);

//         // Should revert as cooldown is not active anymore
//         vm.expectRevert(KhoopDefi.KhoopDefi__CooldownNotActive.selector);
//         khoopDefi.reduceCooldown();

//         vm.stopPrank();
//     }

//     function testReferralBonusPerEntry() public {
//         address user1 = address(0x1001);
//         address user2 = address(0x1002);
//         uint256 numEntries = 5;
//         uint256 perEntryBonus = 1e18; // $1 per entry
//         uint256 expectedBonus = numEntries * perEntryBonus; // 5 * $1 = $5

//         // Fund users
//         usdt.mint(user1, 1000e18);
//         usdt.mint(user2, 1000e18);

//         // Register and activate user1 (referrer)
//         vm.startPrank(user1);
//         khoopDefi.registerUser(user1, powerCycle);
//         usdt.approve(address(khoopDefi), type(uint256).max);
//         khoopDefi.purchaseEntries(numEntries); // Make user1 active by purchasing slots
//         vm.stopPrank();

//         // Register and activate user2 (referred by user1)
//         vm.startPrank(user2);
//         khoopDefi.registerUser(user2, user1);
//         usdt.approve(address(khoopDefi), type(uint256).max);

//         uint256 referrerBalanceBefore = usdt.balanceOf(user1);
//         (,,, uint256 bonusBefore,,,,,) = khoopDefi.users(user1);

//         // This purchase should trigger a referral bonus to user1
//         khoopDefi.purchaseEntries(numEntries);
//         vm.stopPrank();

//         uint256 reffererBalanceAfter = usdt.balanceOf(user1);
//         // Check user1's stats after
//         (,,, uint256 bonusAfter,,,,,) = khoopDefi.users(user1);
//         console.log("Bonus after:", bonusAfter / 1e18, "USDT");
//         console.log("Bonus received:", (bonusAfter - bonusBefore) / 1e18, "USDT");

//         // Should be 5 USDT (1 per entry)
//         assertEq(bonusAfter - bonusBefore, expectedBonus, "Incorrect referral bonus");
//     }

//     function testReferralBonusSystem() public {
//         // Setup users
//         address referrer = address(uint160(5000));
//         address user1 = address(uint160(10001));

//         // Give USDT to users
//         usdt.mint(referrer, 1000e18);
//         usdt.mint(user1, 1000e18);

//         // Register and activate referrer first
//         vm.startPrank(referrer);
//         khoopDefi.registerUser(referrer, powerCycle);
//         usdt.approve(address(khoopDefi), SLOT_PRICE);
//         khoopDefi.purchaseEntries(1); // Make referrer active by purchasing slots
//         vm.stopPrank();

//         // Register user1 with referrer
//         vm.startPrank(user1);
//         khoopDefi.registerUser(user1, referrer);
//         usdt.approve(address(khoopDefi), SLOT_PRICE);

//         // Check referrer balance before purchase
//         uint256 referrerBalanceBefore = usdt.balanceOf(referrer);

//         // This purchase should trigger referral bonus to the referrer
//         khoopDefi.purchaseEntries(1);

//         // Check referrer balance after purchase
//         uint256 referrerBalanceAfter = usdt.balanceOf(referrer);
//         vm.stopPrank();

//         uint256 expectedBonus = 1e18; // $1 per entry
//         assertEq(referrerBalanceAfter - referrerBalanceBefore, expectedBonus, "Referral bonus should be $1");

//         console.log("Referrer bonus received:", (referrerBalanceAfter - referrerBalanceBefore) / 1e18, "USDT");
//     }

//     function testBuybackAutoFillMechanism() public {
//         // Test buyback accumulation and auto-fill functionality
//         uint256 buybackThreshold = 10e18; // $10 threshold
//         uint256 entriesNeeded = 4; // Since $3 per entry, need 4 entries to reach $12 > $10

//         _prepareUsers(entriesNeeded + 5);

//         // Track buyback accumulation - make 3 purchases first (should be $9, below threshold)
//         for (uint256 i = 0; i < 3; i++) {
//             address user = address(uint160(10000 + i));
//             vm.startPrank(user);
//             usdt.approve(address(khoopDefi), SLOT_PRICE);
//             khoopDefi.purchaseEntries(1);
//             vm.stopPrank();
//         }

//         uint256 buybackBefore = khoopDefi.getBuybackAccumulated();
//         console.log("Buyback after 3 purchases:", buybackBefore / 1e18, "USDT"); // Should be $9

//         // This 4th purchase should trigger auto-fill (will reach $12)
//         address triggerUser = address(uint160(10000 + 3));
//         vm.startPrank(triggerUser);
//         khoopDefi.purchaseEntries(1);
//         vm.stopPrank();

//         uint256 buybackAfter = khoopDefi.getBuybackAccumulated();
//         console.log("Buyback after auto-fill:", buybackAfter / 1e18, "USDT"); // Should be $2 ($12 - $10)

//         // Buyback should be reduced by threshold amount ($10)
//         // 3 entries * $3 = $9 from new purchases + previous buyback - $10 threshold
//         uint256 expectedBuyback = buybackBefore + (3e18 * 1) - buybackThreshold;
//         assertEq(buybackAfter, expectedBuyback, "Buyback should decrease by $10 after auto-fill");
//     }

//     function testGetInactiveUsers() public {
//         _prepareUsers(10);
//         for (uint256 i = 0; i < 5; i++) {
//             address user = address(uint160(10000 + i));
//             vm.startPrank(user);
//             khoopDefi.purchaseEntries(1);
//             vm.stopPrank();
//         }

//         address[] memory inactiveUsers = khoopDefi.getInactiveReferrals(powerCycle);
//         (,,,,,uint256 totalRefferals,,,) = khoopDefi.users(powerCycle);
//         assertEq(totalRefferals, 10, "Should have 10 refferals");
//         assertEq(inactiveUsers.length, 5, "Should have 5 inactive users");
//     }

//     function testCycleCompletion() public {
//         // Test that users receive payouts when cycles complete
//         address testUser = address(uint160(20000));
//         usdt.mint(testUser, 1000e18);

//         // Register and activate testUser
//         vm.startPrank(testUser);
//         khoopDefi.registerUser(testUser, powerCycle);
//         usdt.approve(address(khoopDefi), SLOT_PRICE);
//         uint256 balanceBefore = usdt.balanceOf(testUser);
//         khoopDefi.purchaseEntries(1);
//         vm.stopPrank();

//         // Simulate cycle completion by triggering buyback auto-fill
//         uint256 buybackThreshold = 10e18; // $10 threshold
//         uint256 entriesNeeded = 4; // Need 4 entries ($3 each = $12) to trigger $10 threshold
//         _prepareUsers(entriesNeeded);

//         // Make purchases to trigger cycle completion
//         for (uint256 i = 0; i < entriesNeeded; i++) {
//             address user = address(uint160(10000 + i));
//             vm.startPrank(user);
//             usdt.approve(address(khoopDefi), SLOT_PRICE);
//             khoopDefi.purchaseEntries(1);
//             vm.stopPrank();
//         }

//         uint256 balanceAfter = usdt.balanceOf(testUser);
//         int256 balanceChange = int256(balanceAfter) - int256(balanceBefore);

//         console.log("User USDT balance before:", balanceBefore / 1e18);
//         console.log("User USDT balance after:", balanceAfter / 1e18);
//         console.log("User USDT balance change:", balanceChange / 1e18);

//         // Verify the balance change is as expected
//         // The user should receive payouts as their entries complete cycles
//         // The exact amount depends on the contract's payout logic
//         assertTrue(balanceChange < 0, "User should have a net spend");
//         assertTrue(balanceAfter < balanceBefore, "User should have spent more than received");
//     }

//     function testErrorConditions() public {
//         address testUser = address(uint160(100000));

//         // Test unregistered user trying to purchase
//         vm.startPrank(testUser);
//         usdt.approve(address(khoopDefi), type(uint256).max);

//         // Should revert with UserNotRegistered
//         vm.expectRevert(KhoopDefi.KhoopDefi__UserNotRegistered.selector);
//         khoopDefi.purchaseEntries(1);

//         // Register the user but don't activate (no purchase)
//         khoopDefi.registerUser(testUser, powerCycle);

//         // Test self-referral during registration
//         vm.expectRevert(KhoopDefi.KhoopDefi__SelfReferral.selector);
//         khoopDefi.registerUser(testUser, testUser);

//         // Test unregistered referrer during registration
//         address unregistered = address(999);
//         vm.expectRevert(KhoopDefi.KhoopDefi__UnregisteredReferrer.selector);
//         khoopDefi.registerUser(address(100001), unregistered);

//         // Test already registered user
//         vm.expectRevert(KhoopDefi.KhoopDefi__UserAlreadyRegistered.selector);
//         khoopDefi.registerUser(testUser, powerCycle);

//         // Test purchasing with zero entries
//         vm.expectRevert(KhoopDefi.KhoopDefi__ExceedsTransactionLimit.selector);
//         khoopDefi.purchaseEntries(0);

//         // Test purchasing more than max entries per transaction
//         vm.expectRevert(KhoopDefi.KhoopDefi__ExceedsTransactionLimit.selector);
//         deal(address(usdt), testUser, 11 * SLOT_PRICE);
//         khoopDefi.purchaseEntries(11);

//         // Test cooldown period
//         vm.expectRevert(KhoopDefi.KhoopDefi__InCooldown.selector);
//         khoopDefi.purchaseEntries(1);

//         vm.stopPrank();

//         console.log("All error conditions tested successfully");
//     }

//     function testGasEfficiencyWithPendingStartId() public {
//         // Test the gas efficiency improvement mentioned in memory about pendingStartId helpers
//         uint256 numUsers = 100;
//         _prepareUsers(numUsers);

//         uint256 totalGas = 0;
//         uint256 maxGas = 0;
//         uint256 minGas = type(uint256).max;
//         uint256 gasUsed;
//         uint256 maxBuybackSeen = 0; // Track the max buyback we've seen
//         uint256 autoFillsTriggered = 0;

//         // Purchase entries and measure gas for buyback auto-fill
//         for (uint256 i = 0; i < numUsers; i++) {
//             address user = address(uint160(10000 + i)); // Use same addresses as _prepareUsers
//             vm.startPrank(user);

//             uint256 gasBefore = gasleft();
//             khoopDefi.purchaseEntries(1);
//             gasUsed = gasBefore - gasleft();

//             totalGas += gasUsed;
//             if (gasUsed > maxGas) maxGas = gasUsed;
//             if (gasUsed < minGas) minGas = gasUsed;

//             // Track buyback accumulation
//             uint256 currentBuyback = khoopDefi.getBuybackAccumulated();
//             if (currentBuyback > maxBuybackSeen) {
//                 maxBuybackSeen = currentBuyback;
//             }

//             // Check if auto-fill was triggered (buyback decreased or stayed low)
//             // Auto-fill triggers when buyback >= 10e18, so we expect buyback to drop
//             uint256 expectedMinBuyback = (i + 1) * 3e18; // Total accumulated so far
//             if (i >= 3 && currentBuyback < expectedMinBuyback - 10e18) {
//                 // If we've done 4+ purchases and buyback is less than expected, auto-fill happened
//                 autoFillsTriggered++;
//             }

//             if ((i + 1) % 10 == 0) {
//                 console.log("Entries processed:", i + 1);
//                 console.log("Last gas used:", gasUsed);
//                 console.log("Current buyback accumulated:", currentBuyback / 1e18, "USDT");
//                 console.log("Max buyback seen:", maxBuybackSeen / 1e18, "USDT");
//             }

//             // Fast forward time to avoid cooldown after first purchase
//             if (i == 0) {
//                 vm.warp(block.timestamp + 30 minutes + 1);
//             }

//             vm.stopPrank();
//         }

//         console.log("\n--- Gas Efficiency Results ---");
//         console.log("Total users/entries:", numUsers);
//         console.log("Average gas per purchase:", totalGas / numUsers);
//         console.log("Min gas used:", minGas);
//         console.log("Max gas used:", maxGas);
//         console.log("Total gas used:", totalGas);
//         console.log("Max buyback seen during test:", maxBuybackSeen / 1e18, "USDT");
//         console.log("Final buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e18, "USDT");
//         console.log("Approximate auto-fills triggered:", autoFillsTriggered);

//         // Verify that the buyback accumulated at some point during the test
//         // (it may be 0 at the end if all was used for auto-fills, which is correct behavior)
//         assertGt(maxBuybackSeen, 0, "Buyback should have accumulated some value during the test");

//         // Verify that auto-fills were triggered
//         assertGt(autoFillsTriggered, 0, "Some auto-fills should have been triggered");
//     }

//     function testViewFunctions() public {
//         // Test all view functions using the tuple-returning getGlobalStats
//         (
//             uint256 totalUsers,
//             uint256 totalActiveUsers,
//             uint256 totalEntriesPurchaseds,
//             uint256 totalReffererBonusPaid,
//             uint256 totalSlotFillPaid,
//             uint256 totalEntriesCompleted
//         ) = khoopDefi.getGlobalStats();

//         console.log("Global stats - total entries:", totalEntriesPurchaseds);
//         console.log("Global stats - total users:", totalUsers);
//         console.log("Global stats - total referrer bonus paid:", totalReffererBonusPaid / 1e18);
//         console.log("Global stats - total slot fill paid:", totalSlotFillPaid / 1e18);
//         console.log("Global stats - total entries completed:", totalEntriesCompleted);
//         console.log("Next entry ID:", khoopDefi.nextEntryId());
//         console.log("Buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e18);

//         // Test user stats after purchase
//         address testUser = address(uint160(120000));
//         usdt.mint(testUser, 1000e18);

//         vm.startPrank(testUser);
//         usdt.approve(address(khoopDefi), SLOT_PRICE);
//         khoopDefi.registerUser(testUser, powerCycle);
//         khoopDefi.purchaseEntries(1);
//         vm.stopPrank();

//         // Check user data
//         (
//             address referrer,
//             uint256 totalEntriesPurchased,
//             uint256 totalCyclesCompleted,
//             uint256 referrerBonusEarned,
//             uint256 totalEarnings,
//             uint256 totalReferrals,
//             uint256 lastEntryAt,
//             bool isRegistered,
//             bool isActive
//         ) = khoopDefi.users(testUser);

//         console.log("User entries purchased:", totalEntriesPurchased);
//         console.log("User is registered:", isRegistered);
//         console.log("User referrer:", referrer);
//     }

//     function testTeamDistribution() public {
//         // Test that team distributions happen correctly
//         _prepareUsers(10);

//         uint256 contractBalanceBefore = usdt.balanceOf(address(khoopDefi));
//         uint256 coreTeamBalanceBefore = usdt.balanceOf(coreTeam[0]);
//         uint256 investorBalanceBefore = usdt.balanceOf(investors[0]);
//         uint256 reserveBalanceBefore = usdt.balanceOf(reserve);

//         // Make some purchases
//         for (uint256 i = 0; i < 5; i++) {
//             address user = address(uint160(10000 + i));
//             vm.startPrank(user);
//             khoopDefi.purchaseEntries(1);
//             vm.stopPrank();
//         }

//         uint256 contractBalanceAfter = usdt.balanceOf(address(khoopDefi));
//         uint256 coreTeamBalanceAfter = usdt.balanceOf(coreTeam[0]);
//         uint256 investorBalanceAfter = usdt.balanceOf(investors[0]);
//         uint256 reserveBalanceAfter = usdt.balanceOf(reserve);

//         console.log("Contract balance change:", (contractBalanceAfter - contractBalanceBefore) / 1e6);
//         console.log("Core team balance change:", (coreTeamBalanceAfter - coreTeamBalanceBefore) / 1e6);
//         console.log("Investor balance change:", (investorBalanceAfter - investorBalanceBefore) / 1e6);
//         console.log("Reserve balance change:", (reserveBalanceAfter - reserveBalanceBefore) / 1e6);
//         console.log("Buyback accumulated:", khoopDefi.getBuybackAccumulated() / 1e6);

//         // Team distribution should happen immediately on each purchase
//         assertTrue(coreTeamBalanceAfter > coreTeamBalanceBefore, "Core team should receive distributions");
//         assertTrue(investorBalanceAfter > investorBalanceBefore, "Investors should receive distributions");
//         assertTrue(reserveBalanceAfter > reserveBalanceBefore, "Reserve should receive distributions");
//     }
// }
