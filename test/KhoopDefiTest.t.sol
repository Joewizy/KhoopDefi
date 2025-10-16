// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";
import {KhoopDefiV2} from "../src/v1.sol";

contract KhoopDefiTest is Test {
    // KhoopDefi public khoopDefi;
    MockUSDT public usdt;
    KhoopDefiV2 public khoopDefi;

    address[4] coreTeam;
    address[15] investors;
    address reserve;
    address buyback;
    address powerCycle;

    uint256 public constant SLOT_PRICE = 15e18;
    uint256 public constant USDT_DECIMALS = 10 ** 18;
    uint256 public constant STARTING_AMOUNT = SLOT_PRICE * 20;
    address user = makeAddr("user");
    address test1 = makeAddr("test1");
    address test2 = makeAddr("test2");
    address test3 = makeAddr("test3");

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

        khoopDefi = new KhoopDefiV2(coreTeam, investors, reserve, powerCycle, address(usdt));
    }

    function testPurchaseEntries() public {
        _registerUser(user);
        vm.startPrank(user);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();
    }

    function testExpectedPayout() public {
        _registerUser(user);
        _registerUser(test1);
        _registerUser(test2);
        _registerUser(test3);
       // usdt.mint(address(khoopDefi), 100e18);

        vm.prank(user);
        khoopDefi.purchaseEntries(1);
        (
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 totalEarnings,
            uint256 totalReferrals,
            bool isActive
        ) = khoopDefi.getUserStats(user);
        console.log("==== Test For Slot1 ====");
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Total earnings: ", totalEarnings);
        console.log("Contract balance after 1st purchase: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        vm.prank(test1);
        khoopDefi.purchaseEntries(1);
        (totalEntriesPurchased, totalCyclesCompleted, referrerBonusEarned, totalEarnings, totalReferrals, isActive) =
            khoopDefi.getUserStats(test1);
        console.log("==== Test For Slot2 ====");
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Total earnings: ", totalEarnings);
        console.log("Contract balance after 2nd purchase: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        vm.prank(test2);
        khoopDefi.purchaseEntries(1);
        (totalEntriesPurchased, totalCyclesCompleted, referrerBonusEarned, totalEarnings, totalReferrals, isActive) =
            khoopDefi.getUserStats(test2);
        console.log("==== Test For Slot3 ====");
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Total earnings: ", totalEarnings);
        console.log("Contract balance after 3rd purchase: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        vm.prank(test3);
        khoopDefi.purchaseEntries(1);
        (totalEntriesPurchased, totalCyclesCompleted, referrerBonusEarned, totalEarnings, totalReferrals, isActive) =
            khoopDefi.getUserStats(test3);
        console.log("==== Test For Slot4 ====");
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Total earnings: ", totalEarnings);
        console.log("Contract balance after 4th purchase: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        console.log("Pending cycles count: ", khoopDefi.getPendingCyclesCount());
        console.log("Contract balance ending: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        for (uint256 i = 1; i <= 4; i++) {
            (address owner,, uint8 cyclesCompleted, uint256 lastCycleTimestamp, bool isActive, uint8 cyclesRemaining) =
                khoopDefi.getEntryDetails(i);
            console.log("Owner: ", owner);
            console.log("Cycles completed: ", cyclesCompleted);
            console.log("Last cycle timestamp: ", lastCycleTimestamp);
            console.log("Is active: ", isActive);
            console.log("Cycles remaining: ", cyclesRemaining);
        }
    }

    function testMultipleUsers() public {
        _registerUser(user);
        _registerUser(test1);
        _registerUser(test2);
        _registerUser(test3);
        uint256 initialGas = gasleft();

        vm.startPrank(user);
        console.log("Contract balance before user purchase: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        khoopDefi.purchaseEntries(10);
        console.log("Contract balance after user purchase 10 slots: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        vm.stopPrank();

        vm.startPrank(test1);
        uint256[] memory userActiveEntries = khoopDefi.getUserActiveEntries(user);
        _getUserActiveEntriesDetails(user);
        console.log("User Active Entries after 10 buy: ", userActiveEntries.length);
        khoopDefi.purchaseEntries(10);
        console.log("Contract balance after test1 purchase 10 slots: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        console.log("After test1 bought 10 entries:");
        _getUserActiveEntriesDetails(user);
        console.log("Test 1 entry details");
        (address owner,, uint8 cyclesCompleted, uint256 lastCycleTimestamp, bool isActive, uint8 cyclesRemaining) = khoopDefi.getEntryDetails(20);
        console.log("Test 1 last entry should get at least one cycle");
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Last cycle timestamp: ", lastCycleTimestamp);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);
        vm.stopPrank();

        vm.startPrank(test2);
        uint256[] memory test1ActiveEntries = khoopDefi.getUserActiveEntries(test1);
        _getUserActiveEntriesDetails(test1);
        console.log("Test1 Active Entries after 10 buy: ", test1ActiveEntries.length);
        khoopDefi.purchaseEntries(10);
        console.log("Contract balance after test2 purchase 10 slots: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        console.log("Test 2 entry details");
        khoopDefi.getEntryDetails(20);
        vm.stopPrank();

        vm.startPrank(test3);
        uint256[] memory test2ActiveEntries = khoopDefi.getUserActiveEntries(test2);
        _getUserActiveEntriesDetails(test2);
        console.log("Test2 Active Entries after 10 buy: ", test2ActiveEntries.length);
        khoopDefi.purchaseEntries(10);
        console.log("Contract balance after test3 purchase 10 slots: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        vm.stopPrank();
        uint256 finalGas = gasleft();

        uint256[] memory test3ActiveEntries = khoopDefi.getUserActiveEntries(test3);
        _getUserActiveEntriesDetails(test3);
        console.log("Test3 Active Entries after 10 buy: ", test3ActiveEntries.length);

        console.log("Initial Gas: ", initialGas);
        console.log("Final Gas: ", finalGas);
        console.log("Gas Used: ", initialGas - finalGas);

        uint256[] memory userActiveEntriesFinal = khoopDefi.getUserActiveEntries(user);
        uint256[] memory test1ActiveEntriesFinal = khoopDefi.getUserActiveEntries(test1);
        uint256[] memory test2ActiveEntriesFinal = khoopDefi.getUserActiveEntries(test2);
        uint256[] memory test3ActiveEntriesFinal = khoopDefi.getUserActiveEntries(test3);
        console.log("User Final Active Entries: ", userActiveEntriesFinal.length);
        console.log("Test1 Final Active Entries: ", test1ActiveEntriesFinal.length);
        console.log("Test2 Final Active Entries: ", test2ActiveEntriesFinal.length);
        console.log("Test3 Final Active Entries: ", test3ActiveEntriesFinal.length);
        console.log("Contract balance after test3 purchase 10 slots: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        (uint256 totalUsers, uint256 totalActiveUsers, uint256 totalEntriesPurchased, uint256 totalReferrerBonusPaid, uint256 totalPayoutsMade, uint256 totalCyclesCompleted) = khoopDefi.getGlobalStats();
        console.log("Total users: ", totalUsers);
        console.log("Total active users: ", totalActiveUsers);
        console.log("Total entries purchased: ", totalEntriesPurchased);
        console.log("Total referrer bonus paid: ", totalReferrerBonusPaid / 1e18);
        console.log("Total payouts made: ", totalPayoutsMade / 1e18);
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Total money team accumulated: ", khoopDefi.getTeamAccumulatedBalance() / 1e18);
    }

    // Add this test function to your KhooV2Test.t.sol
    function test1000ActiveUsers() public {
        uint256 userCount = 1000;
        uint256 slotsPerUser = 10; // Each user buys 10 slots
        uint256 totalSlots = userCount * slotsPerUser;

        console.log("\n=== Starting 1000 Users Test ===");
        console.log("Users:", userCount);
        console.log("Slots per user:", slotsPerUser);
        console.log("Total slots to process:", totalSlots);
        console.log("Contract balance:", usdt.balanceOf(address(khoopDefi)) / 1e18);

        // 1. Register all users and buy slots
        uint256 gasStart = gasleft();
        uint256 startTime = block.timestamp;

        // Register users and buy slots in batches to avoid gas issues
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(10000 + i));

            // $150 usdt per user
            usdt.mint(user, SLOT_PRICE * slotsPerUser);
            vm.startPrank(user);
            khoopDefi.registerUser(user, powerCycle);
            usdt.approve(address(khoopDefi), type(uint256).max);

            // Buy slots
            khoopDefi.purchaseEntries(slotsPerUser);
            vm.stopPrank();
        }

        // Verify final state
        (
            uint256 totalUsers,
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            ,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted
        ) = khoopDefi.getGlobalStats();

        console.log("\n=== Test Results ===");
        console.log("Total gas used:", gasStart - gasleft());
        console.log("Total users:", totalUsers);
        console.log("Active users:", totalActiveUsers);
        console.log("Total entries purchased:", totalEntriesPurchased);
        console.log("Total payouts made:", totalPayoutsMade / 1e18);
        console.log("Total cycles completed:", totalCyclesCompleted);
    }

    function testBuyersIsInacticeWhenMaxedOut() public {
        _registerUser(user);
        vm.prank(user);
        khoopDefi.purchaseEntries(1);

        (address owner,, uint8 cyclesCompleted, uint256 lastCycleTimestamp, bool isActive, uint8 cyclesRemaining) =
            khoopDefi.getEntryDetails(1);
        (
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 totalEarnings,
            uint256 totalReferrals,
        ) = khoopDefi.getUserStats(user);
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);
        console.log("User has pending cycles: ", khoopDefi.userHasPendingCycles(user));
        console.log("Total entries purchased: ", totalEntriesPurchased);
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Referrer bonus earned: ", referrerBonusEarned);
        console.log("Total earnings: ", totalEarnings);
        console.log("Total referrals: ", totalReferrals);

        vm.startPrank(test1);
        khoopDefi.registerUser(test1, user);
        usdt.mint(test1, SLOT_PRICE * 2);
        usdt.approve(address(khoopDefi), type(uint256).max);
        khoopDefi.purchaseEntries(2);
        vm.stopPrank();

        console.log("====Maxing Out ====");
        (owner,, cyclesCompleted,, isActive, cyclesRemaining) = khoopDefi.getEntryDetails(1);
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);
        console.log("User has pending cycles: ", khoopDefi.userHasPendingCycles(user));
        (totalEntriesPurchased, totalCyclesCompleted, referrerBonusEarned, totalEarnings, totalReferrals, isActive) =
            khoopDefi.getUserStats(user);
        console.log("Total entries purchased: ", totalEntriesPurchased);
        console.log("Total cycles completed: ", totalCyclesCompleted);
        console.log("Referrer bonus earned: ", referrerBonusEarned);
        console.log("Total earnings: ", totalEarnings);
        console.log("Total referrals: ", totalReferrals);

        (owner,, cyclesCompleted,, isActive, cyclesRemaining) = khoopDefi.getEntryDetails(2);
        console.log("Entry 2");
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);

        (owner,, cyclesCompleted,, isActive, cyclesRemaining) = khoopDefi.getEntryDetails(3);
        console.log("Entry 3");
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);

        console.log("contract balance before donating: ", usdt.balanceOf(address(khoopDefi)) / 1e18);

        uint256 pendingCycles = 25e18;
        vm.prank(user);
        khoopDefi.donateToSystem(pendingCycles);
        console.log("contract balance after donating: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        vm.prank(user);
        khoopDefi.donateToSystem(pendingCycles);
        console.log("contract balance after donating again: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        (owner,, cyclesCompleted,, isActive, cyclesRemaining) = khoopDefi.getEntryDetails(2);
        console.log("Entry 2 After processing");
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);

        (owner,, cyclesCompleted,, isActive, cyclesRemaining) = khoopDefi.getEntryDetails(3);
        console.log("Entry 3 After processing");
        console.log("Owner: ", owner);
        console.log("Cycles completed: ", cyclesCompleted);
        console.log("Is active: ", isActive);
        console.log("Cycles remaining: ", cyclesRemaining);

        console.log("Final contract balance: ", usdt.balanceOf(address(khoopDefi)) / 1e18);
        assertEq(khoopDefi.isUserActive(user), false);
        assertEq(khoopDefi.isUserActive(test1), false);

        // No active cycles
        vm.expectRevert(KhoopDefi.KhoopDefi__NoActiveCycles.selector);
        khoopDefi.completeCycles();
    }

    // should write an invaraint test that the contract balance would always be less than $3 expected top up manually

    function _registerUser(address user) internal {
        usdt.mint(user, STARTING_AMOUNT);
        vm.startPrank(user);
        khoopDefi.registerUser(user, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        vm.stopPrank();
    }

    function _prepareUsers(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            address user = address(uint160(10000 + i));
            usdt.mint(user, 1000e18);
            vm.startPrank(user);
            _registerUser(user);
            usdt.approve(address(khoopDefi), SLOT_PRICE * 11);
            vm.stopPrank();
        }
    }

    function _getUserActiveEntriesDetails(address user) internal view returns (uint256, uint256) {
        uint256[] memory activeEntries = khoopDefi.getUserActiveEntries(user);
        uint256 totalActiveEntries = activeEntries.length;
        uint256 totalCyclesCompleted = 0;
        
        for (uint256 i = 0; i < activeEntries.length; i++) {
            // Use getEntryDetails to get the full entry data
            (,, uint8 cyclesCompleted,,,) = khoopDefi.getEntryDetails(activeEntries[i]);
            totalCyclesCompleted += cyclesCompleted;
        }
        
        console.log("User:", user);
        console.log("  - Total Active Entries:", totalActiveEntries);
        console.log("  - Total Cycles Completed:", totalCyclesCompleted);
        
        return (totalActiveEntries, totalCyclesCompleted);
}
}
