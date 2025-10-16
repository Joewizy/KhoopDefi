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
        (uint256 totalUsers,, uint256 totalEntries,,,) = khoopDefi.getGlobalStats();
        console.log("Total users:", totalUsers);
        console.log("Total entries purchased:", totalEntries);

        // Get the user's entry count
        (, uint256 entriesPurchased,,,,,,,) = khoopDefi.users(TEST_WALLET); // Removed unused 'referrer' variable
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
        assertEq(cyclesCompleted1, 4, "Entry 1 should have 4 cycles completed");
        assertEq(isActive1, false, "Entry 1 should be inactive");

        // Check entry 2
        (,, uint8 cyclesCompleted2,, bool isActive2,) = khoopDefi.getEntryDetails(2);
        console.log("Cycles completed for entry 2", cyclesCompleted2);
        console.log("Is active for entry 2", isActive2);
        assertEq(cyclesCompleted2, 4, "Entry 2 should have 4 cycles completed");
        assertEq(isActive2, false, "Entry 2 should be inactive");

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
