// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {KhoopDefi} from "../src/KhoopDefi.sol";

contract BuySlotsOnMainnetTest is Test {
    // BSC Mainnet USDT contract - CORRECTED ADDRESS
    IERC20Metadata public constant USDT = IERC20Metadata(0x55d398326f99059fF775485246999027B3197955);

    // Test wallet with BNB for gas and USDT for testing
    address public constant TEST_WALLET = 0x8894E0a0c962CB723c1976a4421c95949bE2D4E3; // Binance 14 wallet
    uint256 public constant FORK_BLOCK = 41000000; // Recent block number for forking

    KhoopDefi public khoopDefi;

    // Using address(this) for all admin addresses to simplify setup
    address[4] public coreTeam;
    address[15] public investors;
    address public reserveWallet;
    address public buybackWallet;
    address public powerCycleWallet;

    address obed = makeAddr("obed");
    address sam = makeAddr("sam");

    function setUp() public {
        // Fork BSC Mainnet
        string memory bscRpcUrl = "https://bnb-mainnet.g.alchemy.com/v2/CsaW4suKyI6SXkAIjbbHc";
        uint256 forkId = vm.createFork(bscRpcUrl);
        vm.selectFork(forkId);

        // Initialize admin addresses
        for (uint256 i = 0; i < 4; i++) {
            coreTeam[i] = address(this);
        }
        for (uint256 i = 0; i < 15; i++) {
            investors[i] = address(this);
        }
        reserveWallet = address(this);
        buybackWallet = address(this);
        powerCycleWallet = address(this);

        // Deploy KhoopDefi contract
        khoopDefi = new KhoopDefi(coreTeam, investors, reserveWallet, powerCycleWallet, address(USDT));

        // Impersonate the test wallet for the test
        vm.startPrank(TEST_WALLET);
        USDT.approve(address(khoopDefi), type(uint256).max);
        vm.stopPrank();
    }

    function testUsdt() public view {
        uint256 balance = USDT.balanceOf(TEST_WALLET);
        console.log("USDT balance:", balance / 1e18, "USDT");
        console.log("USDT decimals:", USDT.decimals());
    }

    function testRealisticDoSScenarioMainnet() public {
        // Setup: Attacker fills queue
        address attacker = address(0x666);
        deal(address(USDT), attacker, 300_000e18); // Reduced to $300k USDT
        console.log("Starting gas", gasleft());

        vm.startPrank(attacker);
        USDT.approve(address(khoopDefi), 300_000e18);
        khoopDefi.registerUser(attacker, powerCycleWallet);

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
        deal(address(USDT), victim, 100e18);

        vm.startPrank(victim);
        USDT.approve(address(khoopDefi), 100e18);
        khoopDefi.registerUser(victim, powerCycleWallet);

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
        deal(address(USDT), address(khoopDefi), 100_000_000e18);
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

    function testBuySlots() public {
        // Number of slots to buy
        uint256 numSlots = 10;

        // Get the test wallet's USDT balance
        uint256 initialBalance = USDT.balanceOf(TEST_WALLET);
        console.log("Initial USDT balance:", initialBalance / 1e18, "USDT");

        // Calculate required USDT (15 USDT per slot)
        uint256 requiredUSDT = 15 * 1e18 * numSlots;

        // Check if test wallet has enough USDT
        require(initialBalance >= requiredUSDT, "Test wallet doesn't have enough USDT");

        // Impersonate the test wallet
        vm.startPrank(TEST_WALLET);

        // Approve KhoopDefi to spend USDT
        USDT.approve(address(khoopDefi), requiredUSDT);

        // Buy slots (using powerCycleWallet as referrer)
        khoopDefi.registerUser(TEST_WALLET, powerCycleWallet);
        khoopDefi.purchaseEntries(numSlots);

        // Verify the purchase
        uint256 finalBalance = USDT.balanceOf(TEST_WALLET);
        console.log("USDT spent:", (initialBalance - finalBalance) / 1e18, "USDT");
        console.log("Remaining USDT balance:", finalBalance / 1e18, "USDT");

        // Verify the purchase was successful by checking the user's entry count
        (uint256 totalUsers,, uint256 totalEntries,,,,,) = khoopDefi.getGlobalStats();
        console.log("Total users:", totalUsers);
        console.log("Total entries purchased:", totalEntries);

        // Get the user's entry count
        (, uint256 entriesPurchased,,,,,,,,) = khoopDefi.users(TEST_WALLET); // Removed unused 'referrer' variable
        console.log("User's total entries:", entriesPurchased);

        // Log the last few entry details (up to 5 to avoid too much output)
        for (uint256 i = 0; i < 5; i++) {
            uint256 entryId = i + 1;
            (address owner,, uint8 cyclesCompleted,, bool isActive,) = khoopDefi.getEntryDetails(entryId);
            console.log("Entry", entryId, ":");
            console.log("  Owner:", owner);
            console.log("  Cycles completed:", uint256(cyclesCompleted));
            console.log("  Is active:", isActive);
        }
        (address owner,, uint8 cyclesCompleted,, bool isActive, uint8 cyclesRemaining) = khoopDefi.getEntryDetails(1);
        console.log("Cycles completed", cyclesCompleted);
        console.log("Cycles remaining", cyclesRemaining);

        // Test topUp to complete slots top up $50 to complete entry 1 and 2
        uint256 amount = 50e18; // top up $50 to complete entry 1 and 2
        address richKid = makeAddr("richKid");
        vm.startPrank(richKid);
        deal(address(USDT), richKid, amount);
        USDT.approve(address(khoopDefi), amount);
        khoopDefi.donateToSystem(amount);
        vm.stopPrank();

        // Check entry 1
        console.log("Code dey reach here so?");
        (,, uint8 cyclesCompleted1,, bool isActive1,) = khoopDefi.getEntryDetails(1);
        console.log("Cycles completed for entry 1", cyclesCompleted1);
        console.log("Is active for entry 1", isActive1);

        // Check entry 2
        (,, uint8 cyclesCompleted2,, bool isActive2,) = khoopDefi.getEntryDetails(2);
        console.log("Cycles completed for entry 2", cyclesCompleted2);
        console.log("Is active for entry 2", isActive2);

        // Log the last few entry details (up to 5 to avoid too much output)
        for (uint256 i = 5; i < 10; i++) {
            uint256 entryId = i + 1;
            (address owner,, uint8 cyclesCompleted,, bool isActive,) = khoopDefi.getEntryDetails(entryId);
            console.log("Entry", entryId, ":");
            console.log("  Owner:", owner);
            console.log("  Cycles completed:", uint256(cyclesCompleted));
            console.log("  Is active:", isActive);
        }
    }
}
