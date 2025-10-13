// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";
import {MockUSDT} from "./mocks/MockUSDT.sol";

contract QueueAnalysisTest is Test {
    KhoopDefi public khoopDefi;
    MockUSDT public usdt;

    address[4] coreTeam;
    address[15] investors;
    address reserve;
    address powerCycle;
    address[] public signers;

    function setUp() public {
        usdt = new MockUSDT();

        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = address(this);
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(this);
        }
        reserve = address(this);
        powerCycle = address(this);
        signers.push(address(1));
        signers.push(address(2));

        khoopDefi = new KhoopDefi(coreTeam, investors, reserve, powerCycle, signers, 2, address(usdt));
    }

    function testDetailedQueueTracking() public {
        console.log("\n=== Detailed Queue Tracking Test ===\n");

        // Create 5 users with different slot counts
        address userA = address(0xAAAA);
        address userB = address(0xBBBB);
        address userC = address(0xCCCC);
        address userD = address(0xDDDD);
        address userE = address(0xEEEE);

        _setupUser(userA, 2); // 2 slots = 8 cycles needed
        _setupUser(userB, 3); // 3 slots = 12 cycles needed
        _setupUser(userC, 1); // 1 slot = 4 cycles needed
        _setupUser(userD, 2); // 2 slots = 8 cycles needed
        _setupUser(userE, 3); // 3 slots = 12 cycles needed

        // Buy slots
        vm.prank(userA);
        khoopDefi.purchaseEntries(2);
        vm.prank(userB);
        khoopDefi.purchaseEntries(3);
        vm.prank(userC);
        khoopDefi.purchaseEntries(1);
        vm.prank(userD);
        khoopDefi.purchaseEntries(2);
        vm.prank(userE);
        khoopDefi.purchaseEntries(3);

        console.log("Initial State:");
        _logQueueState();
        _logUserStats(userA, "UserA");
        _logUserStats(userB, "UserB");
        _logUserStats(userC, "UserC");
        _logUserStats(userD, "UserD");
        _logUserStats(userE, "UserE");

        // Simulate many cycles to complete userC
        for (uint256 i = 0; i < 10; i++) {
            address donor = address(uint160(10000 + i));
            usdt.mint(donor, 100e18);
            vm.startPrank(donor);
            khoopDefi.registerUser(donor, powerCycle);
            usdt.approve(address(khoopDefi), type(uint256).max);
            khoopDefi.purchaseEntries(1);
            vm.stopPrank();
        }

        console.log("\n\nAfter 10 purchases:");
        _logQueueState();
        _logUserStats(userA, "UserA");
        _logUserStats(userB, "UserB");
        _logUserStats(userC, "UserC");
        _logUserStats(userD, "UserD");
        _logUserStats(userE, "UserE");

        // Check if userC got removed
        bool userCInQueue = khoopDefi.getUserRoundInfo(userC);
        console.log("\nUserC still in queue:", userCInQueue);

        // Verify queue integrity
        address[] memory queueOrder = khoopDefi.getQueueOrder();
        uint256 currentQueueIndex = khoopDefi.getCurrentQueueIndex();
        uint256 nextEntryId = khoopDefi.nextEntryId();
        (address nextInLine, uint256 nextInSlot) = khoopDefi.getNextInLine();
        console.log("\nQueue Order after removals:");
        for (uint256 i = 0; i < queueOrder.length; i++) {
            console.log("  [%d] %s", i, queueOrder[i]);
        }
        console.log("Current queue index: %d", currentQueueIndex);
        uint256[] memory activeEntries = khoopDefi.getUserActiveEntries(0x0000000000000000000000000000000000002713);
        console.log("Active entries for user 0x2713: %d", activeEntries.length);
        for (uint256 i = 0; i < activeEntries.length; i++) {
            (address owner,, uint8 cyclesCompleted,, bool isActive, uint8 remaining) =
                khoopDefi.getEntryDetails(activeEntries[i]);
            console.log("  Entry # %d:", activeEntries[i]);
            console.log("    Owner: %s", owner);
            console.log("    Cycles completed: %d", cyclesCompleted);
            console.log("    Is active: %s", isActive);
            console.log("    Remaining: %d", remaining);
        }

        console.log("===== NEXT IN LINE =====");
        console.log("Next in line: %s", nextInLine);
        console.log("Next in slot: %d", nextInSlot);
    }

    function testUser0x2983Tracking() public {
        console.log("\n=== Tracking Specific User 0x2983 ===\n");

        // Recreate the scenario
        uint256 targetUserNum = 627; // User 0x2983 = 10627 - 10000
        address targetUser = address(uint160(10000 + targetUserNum));

        console.log("Target user address:", targetUser);
        console.log("Expected: 0x0000000000000000000000000000000000002983");

        // Register and buy
        _setupUser(targetUser, 10);
        vm.prank(targetUser);
        khoopDefi.purchaseEntries(10);

        // Get user's entries
        uint256[] memory entries = khoopDefi.getUserAllEntries(targetUser);
        console.log("\nUser's entry IDs:");
        for (uint256 i = 0; i < entries.length; i++) {
            (address owner,, uint8 cyclesCompleted,, bool isActive, uint8 remaining) =
                khoopDefi.getEntryDetails(entries[i]);
            console.log(" Entry # %d:", entries[i]);
            console.log(" Owner: %s", owner);
            console.log(" Cycles completed: %d", cyclesCompleted);
            console.log(" Is active: %s", isActive);
            console.log(" Remaining: %d", remaining);
        }

        // Check stats
        (, uint256 cyclesCompleted,,,) = khoopDefi.getUserStats(targetUser);
        console.log("\nTotal cycles completed for user: %d", cyclesCompleted);
    }

    function testEntryOwnershipVerification() public {
        console.log("\n=== Entry Ownership Verification ===\n");

        // Create 10 users with 10 slots each
        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(10000 + i));
            _setupUser(user, 10);
            vm.prank(user);
            khoopDefi.purchaseEntries(10);

            uint256[] memory entries = khoopDefi.getUserAllEntries(user);
            console.log("\nUser %d (address %s):", i, user);
            console.log("  Entry range: %d to %d", entries[0], entries[entries.length - 1]);

            // Verify all entries belong to this user
            for (uint256 j = 0; j < entries.length; j++) {
                (address owner,,,,,) = khoopDefi.getEntryDetails(entries[j]);
                if (owner != user) {
                    console.log("  ERROR: Entry %d belongs to %s, not %s", entries[j], owner, user);
                }
            }
        }
    }

    function _setupUser(address user, uint256 slots) internal {
        usdt.mint(user, 15e18 * slots);
        vm.startPrank(user);
        khoopDefi.registerUser(user, powerCycle);
        usdt.approve(address(khoopDefi), type(uint256).max);
        vm.stopPrank();
    }

    function _logQueueState() internal view {
        uint256 queueLength = khoopDefi.getQueueLength();
        uint256 currentIndex = khoopDefi.getCurrentQueueIndex();
        (address nextUser, uint256 slots) = khoopDefi.getNextInLine();

        console.log("  Queue length: %d", queueLength);
        console.log("  Current index: %d", currentIndex);
        console.log("  Next in line: %s (slots: %d)", nextUser, slots);
    }

    function _logUserStats(address user, string memory name) internal view {
        (, uint256 totalCyclesCompleted,, uint256 earnings,) = khoopDefi.getUserStats(user);
        bool inQueue = khoopDefi.getUserRoundInfo(user);
        console.log("name: %s", name);
        console.log("totalCyclesCompleted: %d", totalCyclesCompleted);
        console.log("earnings: %d", earnings / 1e18);
        console.log("inQueue: %s", inQueue);
    }
}
