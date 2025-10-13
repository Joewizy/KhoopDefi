// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

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
    address[] public signers;
    uint256 public requiredSignatures = 2;

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
        signers.push(test1);
        signers.push(test2);

        khoopDefi = new KhoopDefi(coreTeam, investors, reserve, powerCycle, signers, requiredSignatures, address(usdt));
    }

    function testPurchaseEntries() public {
        _registerUser(user);
        vm.startPrank(user);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();
    }

    function testMultipleUsers() public {
        _registerUser(user);
        _registerUser(test1);
        _registerUser(test2);
        _registerUser(test3);
        uint256 initialGas = gasleft();

        vm.startPrank(user);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test1);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test2);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();

        vm.startPrank(test3);
        khoopDefi.purchaseEntries(10);
        vm.stopPrank();
        uint256 finalGas = gasleft();

        console.log("Initial Gas: ", initialGas);
        console.log("Final Gas: ", finalGas);
        console.log("Gas Used: ", initialGas - finalGas);

        // All testers should have cycles completed
        uint256 pendingCyclesCount = khoopDefi.getPendingCyclesCount();
        console.log("Pending Cycles Count: ", pendingCyclesCount);
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

        uint256 queueIndex = khoopDefi.getCurrentQueueIndex();
        uint256 pendingCyclesCount = khoopDefi.getPendingCyclesCount();
        (address user, uint256 userTotalSlots) = khoopDefi.getNextInLine();
        uint256 queueLength = khoopDefi.getQueueLength();
        address[] memory queueOrder = khoopDefi.getQueueOrder();
        (, uint256 userTotalCyclesCompleted,,,) = khoopDefi.getUserStats(0x0000000000000000000000000000000000002983);
        (address owner,, uint8 cyclesCompleted,, bool isActive, uint8 cyclesRemaining) = khoopDefi.getEntryDetails(6016);
        console.log("Current queue index:", queueIndex);
        console.log("Address at current index", queueOrder[queueIndex]);
        console.log("Pending cycles count:", pendingCyclesCount);
        console.log("Next in line:", user);
        console.log("User total slots:", userTotalSlots);
        console.log("User total cycles completed:", userTotalCyclesCompleted);
        console.log("Queue length:", queueLength);
        console.log("Owner:", owner);
        console.log("Cycles completed:", cyclesCompleted);
        console.log("Is active:", isActive);
        console.log("Cycles remaining:", cyclesRemaining);
    }

    function testBuyersIsInacticeWhenMaxedOut() public {
        _registerUser(user);
        vm.prank(user);
        khoopDefi.purchaseEntries(1);

        (address owner,, uint8 cyclesCompleted,, bool isActive, uint8 cyclesRemaining) = khoopDefi.getEntryDetails(1);
        (
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 totalEarnings,
            uint256 totalReferrals
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
        (totalEntriesPurchased, totalCyclesCompleted, referrerBonusEarned, totalEarnings, totalReferrals) =
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

    function testOnlySignersCanInitiateWithdrawal() public {
        vm.startPrank(user);
        vm.expectRevert(KhoopDefi.KhoopDefi__NotASigner.selector);
        khoopDefi.initiateWithdrawal(user, 100e18);
        vm.stopPrank();
    }

    function testSignersCanInitiateWithdrawl() public {
        vm.prank(signers[0]);
        address to = user;
        uint256 amount = 100e18;
        khoopDefi.initiateWithdrawal(to, amount);
        bytes32 withdrawalId = keccak256(abi.encodePacked(to, amount, block.timestamp, block.prevrandao));
        uint256 startingBalance = usdt.balanceOf(user);

        vm.warp(block.timestamp + 48 hours);
        usdt.mint(address(khoopDefi), amount);

        vm.prank(signers[1]);
        khoopDefi.confirmWithdrawal(withdrawalId);
        assertEq(usdt.balanceOf(user), startingBalance + amount);
    }

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
}
